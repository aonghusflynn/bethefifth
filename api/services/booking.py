import uuid
from sqlalchemy.future import select
from sqlalchemy.ext.asyncio import AsyncSession

from models.booking import Booking
from models.game import Game
from models.user import User
from services.notifications import notification_service


class BookingService:
    async def create_booking(self, db: AsyncSession, game_id: uuid.UUID, player_id: uuid.UUID) -> Booking:
        # Check if user exists
        user_result = await db.execute(select(User).where(User.id == player_id))
        user = user_result.scalar_one_or_none()
        if not user:
            raise ValueError("User not found.")

        # Check if game exists
        game_result = await db.execute(select(Game).where(Game.id == game_id))
        game = game_result.scalar_one_or_none()
        if not game:
            raise ValueError("Game not found.")

        # Check for existing non-cancelled booking
        existing_result = await db.execute(
            select(Booking).where(
                Booking.game_id == game_id,
                Booking.player_id == player_id,
                Booking.status != "cancelled",
            )
        )
        existing = existing_result.scalar_one_or_none()
        if existing:
            raise ValueError("Player already has a booking for this game.")

        # Decide confirmed vs waitlisted status
        if game.current_players < game.max_players:
            status = "confirmed"
            game.current_players += 1
            if game.current_players == game.max_players:
                game.status = "full"
        else:
            status = "waitlisted"

        # Create new booking
        booking = Booking(
            game_id=game_id,
            player_id=player_id,
            status=status,
        )
        db.add(booking)
        await db.commit()
        await db.refresh(booking)
        await db.refresh(game)
        return booking

    async def cancel_booking(self, db: AsyncSession, booking_id: uuid.UUID) -> Booking:
        # Get booking
        booking_result = await db.execute(select(Booking).where(Booking.id == booking_id))
        booking = booking_result.scalar_one_or_none()
        if not booking:
            raise ValueError("Booking not found.")

        if booking.status == "cancelled":
            return booking

        old_status = booking.status
        booking.status = "cancelled"

        # Get game
        game_result = await db.execute(select(Game).where(Game.id == booking.game_id))
        game = game_result.scalar_one_or_none()

        if game and old_status == "confirmed":
            game.current_players = max(0, game.current_players - 1)
            if game.status == "full":
                game.status = "open"

            # Auto-promote first waitlisted player (FIFO)
            waitlist_result = await db.execute(
                select(Booking)
                .where(
                    Booking.game_id == game.id,
                    Booking.status == "waitlisted",
                )
                .order_by(Booking.created_at.asc())
            )
            next_booking = waitlist_result.scalars().first()

            if next_booking:
                next_booking.status = "confirmed"
                game.current_players += 1
                if game.current_players == game.max_players:
                    game.status = "full"


                
                # Send push notification asynchronously
                try:
                    await notification_service.send_push(
                        user_id=str(next_booking.player_id),
                        title="You're off the waitlist!",
                        body=f"You have been confirmed for '{game.title}'!",
                        data={"game_id": str(game.id), "booking_id": str(next_booking.id)},
                    )
                except Exception:
                    # Don't fail the transaction if push notification fails
                    pass

        await db.commit()
        await db.refresh(booking)
        if game:
            await db.refresh(game)
        return booking


booking_service = BookingService()
