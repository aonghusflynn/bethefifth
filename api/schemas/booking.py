import uuid
from datetime import datetime

from pydantic import BaseModel


class BookingResponse(BaseModel):
    id: uuid.UUID
    game_id: uuid.UUID
    player_id: uuid.UUID
    status: str
    created_at: datetime

    model_config = {"from_attributes": True}
