import uuid
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from middleware.auth import get_current_user
from models.user import User
from models.game import Game
from models.booking import Booking
from schemas.game import GameListResponse
from schemas.user import UserResponse, UserUpdate

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me", response_model=UserResponse)
async def get_me(
    current_user: User = Depends(get_current_user),
):
    """Get the authenticated user's profile."""
    return current_user


@router.patch("/me", response_model=UserResponse)
async def update_current_user(
    user_update: UserUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Update the authenticated user's profile."""
    if current_user not in db:
        current_user = await db.merge(current_user)

    update_data = user_update.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(current_user, key, value)

    await db.commit()
    await db.refresh(current_user)
    return current_user


@router.get("/{user_id}/games", response_model=GameListResponse)
async def get_user_games(
    user_id: uuid.UUID,
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
):
    """Get games for a specific user."""
    # Find all games where there is an active (not cancelled) booking for this user
    query = (
        select(Game)
        .join(Booking, Game.id == Booking.game_id)
        .where(Booking.player_id == user_id)
        .where(Booking.status != "cancelled")
        .order_by(Game.starts_at.desc())
    )
    result = await db.execute(query)
    all_games = result.scalars().all()

    total = len(all_games)
    
    # Simple pagination
    start = (page - 1) * per_page
    end = start + per_page
    paginated_games = all_games[start:end]

    return {
        "items": paginated_games,
        "total": total,
        "page": page,
        "per_page": per_page,
    }

