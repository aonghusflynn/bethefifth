import logging
import uuid
from datetime import datetime, timedelta, timezone

from dateutil.rrule import rrulestr
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from models.game import Game
from models.series import GameSeries
from models.squad import Squad
from services.booking import booking_service

logger = logging.getLogger(__name__)


def as_utc(value: datetime) -> datetime:
    """Normalise a datetime to timezone-aware UTC.

    Postgres hands back aware datetimes but SQLite does not, so anything read
    back from the database has to be normalised before it can be compared with
    or fed into rrule alongside aware values.
    """
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


class SeriesService:
    """Turns recurring fixture definitions into concrete, bookable games."""

    def _build_rule(self, rrule: str, dtstart: datetime):
        try:
            return rrulestr(rrule, dtstart=as_utc(dtstart))
        except Exception as e:
            raise ValueError(f"Invalid recurrence rule: {e}") from e

    async def create_series(
        self,
        db: AsyncSession,
        organiser_id: uuid.UUID,
        venue_id: uuid.UUID,
        title: str,
        starts_at: datetime,
        rrule: str,
        squad_id: uuid.UUID | None = None,
        description: str | None = None,
        duration_minutes: int = 60,
        max_players: int = 10,
        skill_level: int = 3,
    ) -> GameSeries:
        # Validate before persisting — a bad rule would otherwise fail silently
        # every time the scheduler ran.
        self._build_rule(rrule, starts_at)

        # Fail fast rather than letting every future materialisation quietly
        # skip the invite step.
        if squad_id is not None:
            squad_result = await db.execute(
                select(Squad).where(Squad.id == squad_id)
            )
            squad = squad_result.scalar_one_or_none()
            if squad is None:
                raise ValueError("Squad not found.")
            if squad.organiser_id != organiser_id:
                raise PermissionError("Only the squad organiser can use it.")

        series = GameSeries(
            organiser_id=organiser_id,
            venue_id=venue_id,
            squad_id=squad_id,
            title=title,
            description=description,
            starts_at=starts_at,
            rrule=rrule,
            duration_minutes=duration_minutes,
            max_players=max_players,
            skill_level=skill_level,
        )
        db.add(series)
        await db.commit()
        await db.refresh(series)
        return series

    async def get_series(
        self, db: AsyncSession, series_id: uuid.UUID
    ) -> GameSeries | None:
        result = await db.execute(
            select(GameSeries).where(GameSeries.id == series_id)
        )
        return result.scalar_one_or_none()

    async def list_series(
        self, db: AsyncSession, organiser_id: uuid.UUID
    ) -> list[GameSeries]:
        result = await db.execute(
            select(GameSeries)
            .where(GameSeries.organiser_id == organiser_id)
            .order_by(GameSeries.created_at.asc())
        )
        return list(result.scalars().all())

    async def _owned_series(
        self, db: AsyncSession, series_id: uuid.UUID, organiser_id: uuid.UUID
    ) -> GameSeries:
        series = await self.get_series(db, series_id)
        if series is None:
            raise ValueError("Series not found.")
        if series.organiser_id != organiser_id:
            raise PermissionError("Only the series organiser can modify it.")
        return series

    async def set_active(
        self,
        db: AsyncSession,
        series_id: uuid.UUID,
        organiser_id: uuid.UUID,
        is_active: bool,
    ) -> GameSeries:
        """Pause or resume a series.

        Deactivating stops future instances being created but deliberately
        leaves already-materialised games alone — people may have booked them.
        """
        series = await self._owned_series(db, series_id, organiser_id)
        series.is_active = is_active
        await db.commit()
        await db.refresh(series)
        return series

    async def delete_series(
        self, db: AsyncSession, series_id: uuid.UUID, organiser_id: uuid.UUID
    ) -> None:
        """Delete a series, detaching any games it already produced.

        Those games keep their bookings and carry on as one-offs; deleting a
        template should not cancel matches people have already committed to.
        """
        series = await self._owned_series(db, series_id, organiser_id)

        result = await db.execute(select(Game).where(Game.series_id == series_id))
        for game in result.scalars().all():
            game.series_id = None
            game.is_recurring = False

        await db.delete(series)
        await db.commit()

    async def materialise_upcoming(
        self,
        db: AsyncSession,
        now: datetime,
        horizon_days: int,
    ) -> list[Game]:
        """Create games for every active series occurring in the next window.

        Idempotent: an occurrence that already has a game is skipped, so this
        can run as often as the scheduler likes. The window is inclusive at
        both ends — [now, now + horizon_days].

        Where a series has a squad, its members are invited to each newly
        created game, which is what produces a notification per instance.
        """
        now = as_utc(now)
        until = now + timedelta(days=horizon_days)

        result = await db.execute(
            select(GameSeries).where(GameSeries.is_active.is_(True))
        )
        all_series = list(result.scalars().all())

        created: list[Game] = []
        for series in all_series:
            try:
                rule = self._build_rule(series.rrule, series.starts_at)
            except ValueError:
                # A malformed rule must not stop other series materialising.
                logger.exception(
                    "Skipping series %s with invalid rrule %r", series.id, series.rrule
                )
                continue

            occurrences = [as_utc(o) for o in rule.between(now, until, inc=True)]
            if not occurrences:
                continue

            existing_result = await db.execute(
                select(Game.starts_at).where(Game.series_id == series.id)
            )
            existing = {as_utc(dt) for dt in existing_result.scalars().all()}

            for occurrence in occurrences:
                if occurrence in existing:
                    continue
                game = Game(
                    organiser_id=series.organiser_id,
                    venue_id=series.venue_id,
                    series_id=series.id,
                    title=series.title,
                    description=series.description,
                    starts_at=occurrence,
                    duration_minutes=series.duration_minutes,
                    max_players=series.max_players,
                    current_players=0,
                    skill_level=series.skill_level,
                    status="open",
                    is_recurring=True,
                )
                db.add(game)
                created.append(game)

        if not created:
            return []

        await db.commit()
        for game in created:
            await db.refresh(game)

        await self._invite_squads(db, all_series, created)
        return created

    async def _invite_squads(
        self,
        db: AsyncSession,
        all_series: list[GameSeries],
        games: list[Game],
    ) -> None:
        squad_by_series = {s.id: s.squad_id for s in all_series}
        organiser_by_series = {s.id: s.organiser_id for s in all_series}

        for game in games:
            squad_id = squad_by_series.get(game.series_id)
            if squad_id is None:
                continue
            try:
                await booking_service.invite_squad(
                    db,
                    game_id=game.id,
                    squad_id=squad_id,
                    organiser_id=organiser_by_series[game.series_id],
                )
            except Exception:
                # One bad squad must not abort the rest of the run — the next
                # tick will retry, since invite_squad is idempotent.
                logger.exception(
                    "Failed to invite squad %s to game %s", squad_id, game.id
                )


series_service = SeriesService()
