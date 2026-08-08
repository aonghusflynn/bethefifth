import uuid
from datetime import datetime

from pydantic import BaseModel, EmailStr, Field


class SquadCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)


class SquadUpdate(BaseModel):
    name: str = Field(min_length=1, max_length=100)


class SquadMemberCreate(BaseModel):
    display_name: str = Field(min_length=1, max_length=100)
    # Email is optional, but without one an unregistered player can never be
    # invited or linked to an account later.
    email: EmailStr | None = None
    phone: str | None = Field(default=None, max_length=20)


class SquadMemberResponse(BaseModel):
    id: uuid.UUID
    squad_id: uuid.UUID
    user_id: uuid.UUID | None
    display_name: str
    invite_email: str | None
    invite_phone: str | None
    status: str
    created_at: datetime

    model_config = {"from_attributes": True}


class SquadResponse(BaseModel):
    id: uuid.UUID
    organiser_id: uuid.UUID
    name: str
    created_at: datetime
    # Counts travel with the summary so a squad list doesn't have to fetch
    # every squad's members just to say how big it is.
    active_member_count: int = 0
    pending_member_count: int = 0

    model_config = {"from_attributes": True}


class SquadDetailResponse(SquadResponse):
    members: list[SquadMemberResponse] = []
