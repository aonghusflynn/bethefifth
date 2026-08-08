import uuid
from datetime import datetime

from pydantic import BaseModel, Field


class SeriesCreate(BaseModel):
    venue_id: uuid.UUID
    # Optional — a series without a squad produces games nobody is auto-invited
    # to, which is useful for fixtures you intend to fill from the marketplace.
    squad_id: uuid.UUID | None = None
    title: str = Field(max_length=200)
    description: str | None = Field(None, max_length=1000)
    # First occurrence; also supplies the time of day for every later instance.
    starts_at: datetime
    # iCalendar RRULE, e.g. "FREQ=WEEKLY;BYDAY=TU".
    rrule: str = Field(max_length=500)
    duration_minutes: int = Field(60, ge=15, le=240)
    max_players: int = Field(10, ge=2, le=30)
    skill_level: int = Field(3, ge=1, le=5)


class SeriesUpdate(BaseModel):
    is_active: bool


class SeriesResponse(BaseModel):
    id: uuid.UUID
    organiser_id: uuid.UUID
    venue_id: uuid.UUID
    squad_id: uuid.UUID | None
    title: str
    description: str | None
    starts_at: datetime
    rrule: str
    duration_minutes: int
    max_players: int
    skill_level: int
    is_active: bool

    model_config = {"from_attributes": True}


class TickResponse(BaseModel):
    materialised: int
    game_ids: list[uuid.UUID]
