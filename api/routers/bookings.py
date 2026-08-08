import uuid
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.future import select
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from middleware.auth import get_current_user
from models.booking import Booking
from models.game import Game
from models.user import User
from schemas.booking import AttendanceRequest, BookingResponse, InviteSquadRequest
from services.booking import INACTIVE_STATUSES, booking_service

router = APIRouter(tags=["bookings"])


def _http_error(exc: ValueError) -> HTTPException:
    detail = str(exc)
    status_code = 404 if "not found" in detail.lower() else 400
    return HTTPException(status_code=status_code, detail=detail)


@router.post("/games/{game_id}/bookings", response_model=BookingResponse, status_code=201)
async def create_booking(
    game_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Join a game (confirm or waitlist)."""
    try:
        booking = await booking_service.create_booking(db, game_id, current_user.id)
        return booking
    except ValueError as e:
        detail = str(e)
        if "not found" in detail.lower():
            raise HTTPException(status_code=404, detail=detail)
        raise HTTPException(status_code=400, detail=detail)


@router.delete("/bookings/{booking_id}", status_code=204)
async def cancel_booking(
    booking_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Cancel a booking. Triggers waitlist promotion if applicable."""
    # Retrieve booking
    booking_result = await db.execute(select(Booking).where(Booking.id == booking_id))
    booking = booking_result.scalar_one_or_none()
    if not booking:
        raise HTTPException(status_code=404, detail="Booking not found.")

    # Retrieve game to check organiser permission
    game_result = await db.execute(select(Game).where(Game.id == booking.game_id))
    game = game_result.scalar_one_or_none()

    # Only the player themselves or the game organiser can cancel
    if booking.player_id != current_user.id and (game is None or game.organiser_id != current_user.id):
        raise HTTPException(status_code=403, detail="You are not authorized to cancel this booking.")

    try:
        await booking_service.cancel_booking(db, booking_id)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post(
    "/games/{game_id}/invitations",
    response_model=list[BookingResponse],
    status_code=201,
)
async def invite_squad(
    game_id: uuid.UUID,
    payload: InviteSquadRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Invite a squad to a game.

    Invitations claim no slots — members are notified and take a slot only when
    they accept. Anyone who already has a booking is skipped, so calling this
    again never overwrites an existing answer.
    """
    try:
        return await booking_service.invite_squad(
            db, game_id=game_id, squad_id=payload.squad_id, organiser_id=current_user.id
        )
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))
    except ValueError as e:
        raise _http_error(e)


@router.post("/games/{game_id}/attendance", response_model=BookingResponse)
async def respond_to_invitation(
    game_id: uuid.UUID,
    payload: AttendanceRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Answer a match invitation.

    Accepting claims a slot first-come-first-served and falls back to the
    waitlist when the game is full. Declining a slot you already held releases
    it and promotes the next player in the queue.
    """
    try:
        return await booking_service.respond_to_invitation(
            db,
            game_id=game_id,
            player_id=current_user.id,
            attending=payload.attending,
        )
    except ValueError as e:
        raise _http_error(e)


@router.get("/games/{game_id}/booking", response_model=BookingResponse)
async def get_my_booking(
    game_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get the current user's active booking for a specific game."""
    result = await db.execute(
        select(Booking).where(
            Booking.game_id == game_id,
            Booking.player_id == current_user.id,
            Booking.status.not_in(INACTIVE_STATUSES),
        )
    )
    booking = result.scalar_one_or_none()
    if not booking:
        raise HTTPException(status_code=404, detail="Booking not found.")
    return booking

