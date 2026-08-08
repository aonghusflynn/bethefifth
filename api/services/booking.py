import logging
import uuid

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from models.booking import Booking
from models.game import Game
from models.squad import Squad, SquadMember
from models.user import User
from services.notifications import notification_service

logger = logging.getLogger(__name__)

# Statuses that mean "this player is not occupying or queueing for a slot".
INACTIVE_STATUSES = ("cancelled", "declined")


class BookingService:
    async def _lock_game(self, db: AsyncSession, game_id: uuid.UUID) -> Game | None:
        """Load a game with a row lock held for the rest of the transaction.

        Slot allocation is a read-modify-write on `current_players`. Without
        this lock, a squad all responding to the same push at once can each
        read the same pre-increment count and oversubscribe the game.

        SQLite ignores row locking, so the test suite exercises the same code
        path without it.
        """
        result = await db.execute(
            select(Game).where(Game.id == game_id).with_for_update()
        )
        return result.scalar_one_or_none()

    async def _claim_slot(self, game: Game) -> str:
        """Take a slot if one is free, otherwise join the queue.

        Caller must already hold the game row lock.
        """
        if game.current_players < game.max_players:
            game.current_players += 1
            if game.current_players >= game.max_players:
                game.status = "full"
            return "confirmed"
        return "waitlisted"

    async def _release_slot(self, db: AsyncSession, game: Game) -> None:
        """Give back a confirmed slot and promote the next player in the queue.

        Caller must already hold the game row lock.
        """
        game.current_players = max(0, game.current_players - 1)
        if game.status == "full":
            game.status = "open"

        waitlist_result = await db.execute(
            select(Booking)
            .where(Booking.game_id == game.id, Booking.status == "waitlisted")
            .order_by(Booking.created_at.asc())
        )
        next_booking = waitlist_result.scalars().first()
        if next_booking is None:
            return

        next_booking.status = "confirmed"
        game.current_players += 1
        if game.current_players >= game.max_players:
            game.status = "full"

        try:
            await notification_service.send_push(
                user_id=str(next_booking.player_id),
                title="You're off the waitlist!",
                body=f"You have been confirmed for '{game.title}'!",
                data={"game_id": str(game.id), "booking_id": str(next_booking.id)},
            )
        except Exception:
            # A failed push must not roll back a valid promotion.
            logger.exception("Failed to notify promoted player %s", next_booking.player_id)

    async def get_player_booking(
        self, db: AsyncSession, game_id: uuid.UUID, player_id: uuid.UUID
    ) -> Booking | None:
        result = await db.execute(
            select(Booking).where(
                Booking.game_id == game_id, Booking.player_id == player_id
            )
        )
        return result.scalar_one_or_none()

    async def create_booking(
        self, db: AsyncSession, game_id: uuid.UUID, player_id: uuid.UUID
    ) -> Booking:
        """Join a game directly — the marketplace path, no invitation needed."""
        user_result = await db.execute(select(User).where(User.id == player_id))
        if user_result.scalar_one_or_none() is None:
            raise ValueError("User not found.")

        game = await self._lock_game(db, game_id)
        if game is None:
            raise ValueError("Game not found.")

        existing_result = await db.execute(
            select(Booking).where(
                Booking.game_id == game_id,
                Booking.player_id == player_id,
                Booking.status.not_in(INACTIVE_STATUSES),
            )
        )
        if existing_result.scalar_one_or_none() is not None:
            raise ValueError("Player already has a booking for this game.")

        status = await self._claim_slot(game)

        booking = Booking(game_id=game_id, player_id=player_id, status=status)
        db.add(booking)
        await db.commit()
        await db.refresh(booking)
        await db.refresh(game)
        return booking

    async def invite_squad(
        self,
        db: AsyncSession,
        game_id: uuid.UUID,
        squad_id: uuid.UUID,
        organiser_id: uuid.UUID,
    ) -> list[Booking]:
        """Invite every registered squad member to a game.

        Invitations do not consume slots — a slot is only taken when someone
        accepts. Members who already have a booking are left untouched, so
        re-inviting never resets an existing answer.
        """
        game = await self._lock_game(db, game_id)
        if game is None:
            raise ValueError("Game not found.")
        if game.organiser_id != organiser_id:
            raise PermissionError("Only the game organiser can invite players.")

        squad_result = await db.execute(select(Squad).where(Squad.id == squad_id))
        squad = squad_result.scalar_one_or_none()
        if squad is None:
            raise ValueError("Squad not found.")
        if squad.organiser_id != organiser_id:
            raise PermissionError("Only the squad organiser can invite it.")

        # Members with no account yet cannot hold a booking; they stay pending
        # in the squad until they register.
        members_result = await db.execute(
            select(SquadMember).where(
                SquadMember.squad_id == squad_id,
                SquadMember.user_id.is_not(None),
            )
        )
        members = list(members_result.scalars().all())

        existing_result = await db.execute(
            select(Booking.player_id).where(Booking.game_id == game_id)
        )
        already_booked = set(existing_result.scalars().all())

        created: list[Booking] = []
        for member in members:
            if member.user_id in already_booked:
                continue
            booking = Booking(
                game_id=game_id, player_id=member.user_id, status="invited"
            )
            db.add(booking)
            created.append(booking)

        await db.commit()
        for booking in created:
            await db.refresh(booking)

        await self._notify_invitees(game, created)
        return created

    async def _notify_invitees(self, game: Game, bookings: list[Booking]) -> None:
        for booking in bookings:
            try:
                await notification_service.send_push(
                    user_id=str(booking.player_id),
                    title=f"Are you playing {game.title}?",
                    body="Tap to let your organiser know if you're in.",
                    data={
                        "type": "match_invitation",
                        "game_id": str(game.id),
                        "booking_id": str(booking.id),
                    },
                )
            except Exception:
                logger.exception(
                    "Failed to send invitation push to %s", booking.player_id
                )

    async def respond_to_invitation(
        self,
        db: AsyncSession,
        game_id: uuid.UUID,
        player_id: uuid.UUID,
        attending: bool,
    ) -> Booking:
        """Record a player's answer to a match invitation.

        Accepting claims a slot first-come-first-served, falling back to the
        waitlist when the game is already full. Declining after having accepted
        releases the slot and promotes whoever is next in the queue.
        """
        game = await self._lock_game(db, game_id)
        if game is None:
            raise ValueError("Game not found.")

        booking = await self.get_player_booking(db, game_id, player_id)
        if booking is None:
            raise ValueError("Invitation not found for this player and game.")

        if attending:
            # Already holding a slot or a queue position — nothing to do.
            if booking.status in ("confirmed", "waitlisted"):
                return booking
            booking.status = await self._claim_slot(game)
        else:
            if booking.status == "confirmed":
                await self._release_slot(db, game)
            booking.status = "declined"

        await db.commit()
        await db.refresh(booking)
        await db.refresh(game)
        return booking

    async def cancel_booking(
        self, db: AsyncSession, booking_id: uuid.UUID
    ) -> Booking:
        booking_result = await db.execute(
            select(Booking).where(Booking.id == booking_id)
        )
        booking = booking_result.scalar_one_or_none()
        if booking is None:
            raise ValueError("Booking not found.")

        if booking.status == "cancelled":
            return booking

        was_confirmed = booking.status == "confirmed"
        booking.status = "cancelled"

        game = await self._lock_game(db, booking.game_id)
        if game is not None and was_confirmed:
            await self._release_slot(db, game)

        await db.commit()
        await db.refresh(booking)
        if game is not None:
            await db.refresh(game)
        return booking


booking_service = BookingService()
