import uuid

from pydantic import BaseModel, Field


class VenueCreate(BaseModel):
    name: str = Field(max_length=200)
    address: str = Field(max_length=500)
    city: str = Field(max_length=100)
    country: str = "Ireland"
    lat: float = Field(ge=-90, le=90)
    lng: float = Field(ge=-180, le=180)
    surface: str | None = None
    pitch_size: str | None = None
    parking: bool | None = None


class VenueResponse(BaseModel):
    id: uuid.UUID
    name: str
    address: str
    city: str
    country: str
    lat: float
    lng: float
    surface: str | None
    pitch_size: str | None
    parking: bool | None
    photo_url: str | None

    model_config = {"from_attributes": True}
