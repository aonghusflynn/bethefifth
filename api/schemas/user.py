import uuid

from pydantic import BaseModel, EmailStr, Field


class UserCreate(BaseModel):
    firebase_uid: str
    email: EmailStr | None = None
    display_name: str | None = None
    photo_url: str | None = None


class UserUpdate(BaseModel):
    display_name: str | None = None
    photo_url: str | None = None
    phone: str | None = None
    position: str | None = None
    skill_level: int | None = Field(None, ge=1, le=5)
    locale: str | None = Field(None, pattern=r"^(en|fr|nl|es|it|de)$")


class UserResponse(BaseModel):
    id: uuid.UUID
    firebase_uid: str
    email: str | None
    display_name: str | None
    photo_url: str | None
    position: str | None
    skill_level: int
    reliability_score: float
    is_organiser: bool
    locale: str
    plan: str

    model_config = {"from_attributes": True}
