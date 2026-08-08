import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, func
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column

from database import Base


class Game(Base):
    __tablename__ = "games"

    id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    organiser_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("users.id"), nullable=False
    )
    venue_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("venues.id"), nullable=False
    )
    # Set when this game was materialised from a recurring series. NULL for
    # one-off games, so a game stays the bookable unit either way.
    series_id: Mapped[uuid.UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("game_series.id"), nullable=True
    )
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str | None] = mapped_column(String(1000))
    starts_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=False)
    duration_minutes: Mapped[int] = mapped_column(Integer, default=60)
    max_players: Mapped[int] = mapped_column(Integer, default=10)
    current_players: Mapped[int] = mapped_column(Integer, default=0)
    skill_level: Mapped[int] = mapped_column(Integer, default=3)
    status: Mapped[str] = mapped_column(String(20), default="open")  # open, full, cancelled, completed
    is_recurring: Mapped[bool] = mapped_column(Boolean, default=False)
    is_private: Mapped[bool] = mapped_column(Boolean, default=False)

    # Marketplace visibility. `squad_only` games are hidden from public
    # discovery and reserved for the organiser's squad; `public` games appear
    # in the marketplace for anyone to claim. Defaults to `public` so one-off
    # games behave exactly as they did before this existed.
    visibility: Mapped[str] = mapped_column(
        String(20), default="public", nullable=False
    )  # squad_only, public
    # When the game reached the marketplace, whether opened by the organiser or
    # automatically because it was still short close to kick-off.
    marketplace_opened_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    # Set once the "still short" push has gone out, so it only ever fires once.
    marketplace_notified_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    # Phase 2: payment fields (nullable until Stripe integration)
    cost_per_player: Mapped[int | None] = mapped_column(Integer, nullable=True)
    currency: Mapped[str | None] = mapped_column(String(3), nullable=True)
    created_at: Mapped[str] = mapped_column(server_default=func.now())
    updated_at: Mapped[str] = mapped_column(server_default=func.now(), onupdate=func.now())
