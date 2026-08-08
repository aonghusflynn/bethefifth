import uuid
from datetime import datetime, timezone

from sqlalchemy import ForeignKey, String, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column

from database import Base


class Booking(Base):
    __tablename__ = "bookings"

    id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    game_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("games.id"), nullable=False
    )
    player_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("users.id"), nullable=False
    )
    status: Mapped[str] = mapped_column(
        String(20), default="confirmed"
    )  # invited, confirmed, waitlisted, declined, cancelled
    # Only `confirmed` occupies a slot and counts toward Game.current_players.
    # `invited` is awaiting a response; `declined`/`cancelled` hold nothing.
    created_at: Mapped[str] = mapped_column(
        server_default=func.now(),
        default=lambda: datetime.now(timezone.utc).isoformat(),
    )

    __table_args__ = (
        UniqueConstraint("game_id", "player_id", name="uq_booking_game_player"),
    )

