import logging
import uuid
from datetime import datetime, timedelta

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from config import get_settings
from models.booking import Booking
from models.game import Game
from models.series import GameSeries
from models.squad import SquadMember
from models.user import User
from services.booking import INACTIVE_STATUSES
from services.i18n import t
from services.notifications import notification_service
from services.series import as_utc

logger = logging.getLogger(__name__)

# Cap on how many people a single spillover blast reaches, so a busy venue
# doesn't turn into a mass notification.
MAX_RECIPIENTS = 50


class MarketplaceService:
    """Spills short-handed games out to players beyond the organiser's squad.

    Two stages, deliberately separated in time. A game still short close to
    kick-off is made publicly visible first, giving people already browsing a
    quiet chance to fill it. Only later, if it is *still* short, does a push go
    out — so a game that filled organically never generates a notification.
    """

    async def _owned_game(
        self, db: AsyncSession, game_id: uuid.UUID, organiser_id: uuid.UUID
    ) -> Game:
        result = await db.execute(select(Game).where(Game.id == game_id))
        game = result.scalar_one_or_none()
        if game is None:
            raise ValueError("Game not found.")
        if game.organiser_id != organiser_id:
            raise PermissionError("Only the game organiser can do that.")
        return game

    async def open_manually(
        self,
        db: AsyncSession,
        game_id: uuid.UUID,
        organiser_id: uuid.UUID,
        now: datetime,
    ) -> Game:
        """Open a game to the marketplace ahead of the automatic deadline."""
        game = await self._owned_game(db, game_id, organiser_id)

        if game.visibility != "public":
            game.visibility = "public"
            game.marketplace_opened_at = as_utc(now)
            await db.commit()
            await db.refresh(game)
        return game

    async def close_manually(
        self, db: AsyncSession, game_id: uuid.UUID, organiser_id: uuid.UUID
    ) -> Game:
        """Pull a game back off the marketplace.

        Refused once someone outside the squad has taken a slot — withdrawing
        the game then would strand a player who already committed to it.
        """
        game = await self._owned_game(db, game_id, organiser_id)

        if await self._has_outside_booking(db, game):
            raise ValueError(
                "Someone outside your squad has already joined this game."
            )

        game.visibility = "squad_only"
        game.marketplace_opened_at = None
        game.marketplace_notified_at = None
        await db.commit()
        await db.refresh(game)
        return game

    async def _squad_member_ids(
        self, db: AsyncSession, game: Game
    ) -> set[uuid.UUID]:
        if game.series_id is None:
            return set()

        series_result = await db.execute(
            select(GameSeries).where(GameSeries.id == game.series_id)
        )
        series = series_result.scalar_one_or_none()
        if series is None or series.squad_id is None:
            return set()

        members_result = await db.execute(
            select(SquadMember.user_id).where(
                SquadMember.squad_id == series.squad_id,
                SquadMember.user_id.is_not(None),
            )
        )
        return set(members_result.scalars().all())

    async def _has_outside_booking(self, db: AsyncSession, game: Game) -> bool:
        squad_ids = await self._squad_member_ids(db, game)

        result = await db.execute(
            select(Booking.player_id).where(
                Booking.game_id == game.id,
                Booking.status.not_in(INACTIVE_STATUSES),
            )
        )
        return any(pid not in squad_ids for pid in result.scalars().all())

    def _shortlist_query(self, now: datetime, until: datetime):
        """Games that are open, in the window, and still short of players."""
        return (
            select(Game)
            .where(
                Game.status == "open",
                Game.starts_at > now,
                Game.starts_at <= until,
                Game.current_players < Game.max_players,
            )
            .order_by(Game.starts_at.asc())
        )

    async def auto_open_due(
        self, db: AsyncSession, now: datetime
    ) -> list[Game]:
        """Publish squad-only games that are still short close to kick-off.

        Idempotent — a game already public is no longer selected.
        """
        now = as_utc(now)
        until = now + timedelta(hours=get_settings().marketplace_auto_open_hours)

        result = await db.execute(
            self._shortlist_query(now, until).where(Game.visibility == "squad_only")
        )
        due = list(result.scalars().all())
        if not due:
            return []

        for game in due:
            game.visibility = "public"
            game.marketplace_opened_at = now

        await db.commit()
        for game in due:
            await db.refresh(game)

        logger.info("Opened %d game(s) to the marketplace", len(due))
        return due

    async def notify_due(self, db: AsyncSession, now: datetime) -> list[Game]:
        """Push still-short public games to plausible nearby players.

        Deliberately later than the auto-open: a game that filled quietly in
        the meantime never reaches this stage, so no one gets a notification
        about a game that no longer needs them.
        """
        now = as_utc(now)
        until = now + timedelta(hours=get_settings().marketplace_notify_hours)

        result = await db.execute(
            self._shortlist_query(now, until).where(
                Game.visibility == "public",
                Game.marketplace_notified_at.is_(None),
            )
        )
        due = list(result.scalars().all())
        if not due:
            return []

        for game in due:
            recipients = await self.find_recipients(db, game)
            await self._push(game, recipients)
            game.marketplace_notified_at = now

        await db.commit()
        for game in due:
            await db.refresh(game)

        return due

    async def find_recipients(
        self, db: AsyncSession, game: Game
    ) -> list[User]:
        """Pick who to tell about a game that needs players.

        Players have no stored location, so proper geo-targeting isn't possible
        yet. Previous attendance at the same venue is the best proxy available:
        it is direct evidence someone is willing to travel there. Anyone
        already on this game is excluded.
        """
        already_on_game = await db.execute(
            select(Booking.player_id).where(
                Booking.game_id == game.id,
                Booking.status.not_in(INACTIVE_STATUSES),
            )
        )
        excluded = set(already_on_game.scalars().all())

        history = await db.execute(
            select(Booking.player_id)
            .join(Game, Booking.game_id == Game.id)
            .where(
                Game.venue_id == game.venue_id,
                Game.id != game.id,
                Booking.status.not_in(INACTIVE_STATUSES),
            )
        )
        candidate_ids = {
            pid for pid in history.scalars().all() if pid not in excluded
        }
        if not candidate_ids:
            return []

        users_result = await db.execute(
            select(User).where(User.id.in_(candidate_ids)).limit(MAX_RECIPIENTS)
        )
        return list(users_result.scalars().all())

    async def _push(self, game: Game, recipients: list[User]) -> None:
        slots = max(0, game.max_players - game.current_players)

        for user in recipients:
            try:
                await notification_service.send_push(
                    user_id=str(user.id),
                    title=t("marketplace.push_title", user.locale, title=game.title),
                    body=t(
                        "marketplace.push_body",
                        user.locale,
                        slots=slots,
                        time=as_utc(game.starts_at).strftime("%H:%M"),
                    ),
                    data={
                        "type": "marketplace_spillover",
                        "game_id": str(game.id),
                    },
                )
            except Exception:
                # One bad token must not stop the rest of the blast.
                logger.exception(
                    "Failed to send marketplace push to %s", user.id
                )


marketplace_service = MarketplaceService()
