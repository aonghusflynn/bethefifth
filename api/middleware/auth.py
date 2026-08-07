import uuid

from fastapi import Depends, HTTPException, Request
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from models.user import User
from services.firebase import firebase_service


async def get_firebase_user_claims(
    request: Request,
) -> dict:
    """Extract Bearer token and verify it with Firebase to get claims."""
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing or invalid Authorization header")

    token = auth_header.removeprefix("Bearer ")
    decoded = await firebase_service.verify_token(token)
    if decoded is None:
        raise HTTPException(status_code=401, detail="Invalid or expired token")

    return decoded


async def get_current_user(
    claims: dict = Depends(get_firebase_user_claims),
    db: AsyncSession = Depends(get_db),
) -> User:
    """Look up the User in the DB using verified Firebase claims."""
    firebase_uid = claims.get("uid")
    result = await db.execute(select(User).where(User.firebase_uid == firebase_uid))
    user = result.scalar_one_or_none()

    if user is None:
        raise HTTPException(status_code=404, detail="User not found")

    return user

