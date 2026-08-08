import uuid
from datetime import datetime

from sqlalchemy import (
    Boolean,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    func,
)
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column

from database import Base


class GameSeries(Base):
    """The definition of a repeating fixture — "Tuesdays 7pm at Irishtown".

    A series is a template, not something anyone books. Individual `Game` rows
    are materialised from it ahead of time by
    `SeriesService.materialise_upcoming`, and those are what players actually
    respond to. Keeping `Game` as the bookable instance means everything built
    on it — bookings, waitlists, marketplace discovery — works unchanged
    whether a game came from a series or was a one-off.
    """

    __tablename__ = "game_series"

    id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    organiser_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("users.id"), nullable=False
    )
    venue_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("venues.id"), nullable=False
    )
    # Optional: a series without a squad still materialises games, they just
    # aren't auto-invited to anyone.
    squad_id: Mapped[uuid.UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("squads.id"), nullable=True
    )
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str | None] = mapped_column(String(1000))

    # First occurrence — also the DTSTART the recurrence rule expands from, so
    # it carries the time of day for every future instance.
    starts_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    # iCalendar RRULE, e.g. "FREQ=WEEKLY;BYDAY=TU".
    rrule: Mapped[str] = mapped_column(String(500), nullable=False)

    duration_minutes: Mapped[int] = mapped_column(Integer, default=60)
    max_players: Mapped[int] = mapped_column(Integer, default=10)
    skill_level: Mapped[int] = mapped_column(Integer, default=3)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    __table_args__ = (Index("ix_game_series_organiser_id", "organiser_id"),)
