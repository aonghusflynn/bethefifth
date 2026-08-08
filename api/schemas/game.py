import uuid
from datetime import datetime

from pydantic import BaseModel, Field


class GameCreate(BaseModel):
    venue_id: uuid.UUID
    title: str = Field(max_length=200)
    description: str | None = Field(None, max_length=1000)
    starts_at: datetime
    duration_minutes: int = Field(60, ge=15, le=240)
    max_players: int = Field(10, ge=2, le=30)
    skill_level: int = Field(3, ge=1, le=5)
    is_private: bool = False


class GameUpdate(BaseModel):
    title: str | None = Field(None, max_length=200)
    description: str | None = Field(None, max_length=1000)
    starts_at: datetime | None = None
    max_players: int | None = Field(None, ge=2, le=30)
    skill_level: int | None = Field(None, ge=1, le=5)
    status: str | None = None


class GameResponse(BaseModel):
    id: uuid.UUID
    organiser_id: uuid.UUID
    venue_id: uuid.UUID
    series_id: uuid.UUID | None
    title: str
    description: str | None
    starts_at: datetime
    duration_minutes: int
    max_players: int
    current_players: int
    skill_level: int
    status: str
    is_recurring: bool
    is_private: bool
    cost_per_player: int | None
    currency: str | None

    model_config = {"from_attributes": True}


class GameListResponse(BaseModel):
    items: list[GameResponse]
    total: int
    page: int
    per_page: int
