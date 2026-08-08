import logging

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from middleware.auth import get_firebase_user_claims, get_current_user
from models.user import User
from schemas.user import UserResponse
from services.squad import squad_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=UserResponse, status_code=201)
async def register(
    claims: dict = Depends(get_firebase_user_claims),
    db: AsyncSession = Depends(get_db),
):
    """Register a new user in PostgreSQL after Firebase authentication."""
    firebase_uid = claims.get("uid")
    if not firebase_uid:
        raise HTTPException(status_code=400, detail="Invalid token claims: uid missing")

    # Check if user already exists
    result = await db.execute(select(User).where(User.firebase_uid == firebase_uid))
    existing_user = result.scalar_one_or_none()
    if existing_user is not None:
        raise HTTPException(status_code=400, detail="User already registered")

    # Create new user record
    new_user = User(
        firebase_uid=firebase_uid,
        email=claims.get("email"),
        display_name=claims.get("name"),
        photo_url=claims.get("picture"),
    )
    db.add(new_user)
    await db.commit()
    await db.refresh(new_user)

    # Attach the new account to any squad invites that were waiting on this
    # email address. Never let this block a successful registration.
    try:
        await squad_service.link_pending_members(db, new_user)
    except Exception:
        logger.exception("Failed to link pending squad invites for %s", new_user.id)

    return new_user


@router.post("/login", response_model=UserResponse)
async def login(
    current_user: User = Depends(get_current_user),
):
    """Log in an existing user and return their profile."""
    return current_user

