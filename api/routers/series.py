import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from middleware.auth import get_current_user
from models.user import User
from schemas.series import SeriesCreate, SeriesResponse, SeriesUpdate
from services.series import series_service

router = APIRouter(prefix="/series", tags=["series"])


def _http_error(exc: ValueError) -> HTTPException:
    detail = str(exc)
    status_code = 404 if "not found" in detail.lower() else 400
    return HTTPException(status_code=status_code, detail=detail)


@router.post("/", response_model=SeriesResponse, status_code=201)
@router.post("", response_model=SeriesResponse, status_code=201)
async def create_series(
    payload: SeriesCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Define a repeating fixture.

    Games are not created here — the scheduler materialises them ahead of time
    so that each instance can be invited and responded to separately.
    """
    try:
        return await series_service.create_series(
            db,
            organiser_id=current_user.id,
            venue_id=payload.venue_id,
            squad_id=payload.squad_id,
            title=payload.title,
            description=payload.description,
            starts_at=payload.starts_at,
            rrule=payload.rrule,
            duration_minutes=payload.duration_minutes,
            max_players=payload.max_players,
            skill_level=payload.skill_level,
        )
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))
    except ValueError as e:
        raise _http_error(e)


@router.get("/", response_model=list[SeriesResponse])
@router.get("", response_model=list[SeriesResponse])
async def list_series(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """List the recurring fixtures the current user organises."""
    return await series_service.list_series(db, organiser_id=current_user.id)


@router.get("/{series_id}", response_model=SeriesResponse)
async def get_series(
    series_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    series = await series_service.get_series(db, series_id)
    if series is None:
        raise HTTPException(status_code=404, detail="Series not found.")
    if series.organiser_id != current_user.id:
        raise HTTPException(
            status_code=403, detail="Only the series organiser can view it."
        )
    return series


@router.patch("/{series_id}", response_model=SeriesResponse)
async def update_series(
    series_id: uuid.UUID,
    payload: SeriesUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Pause or resume a series.

    Pausing stops new instances being created but leaves already-scheduled
    games intact, since players may already have committed to them.
    """
    try:
        return await series_service.set_active(
            db,
            series_id=series_id,
            organiser_id=current_user.id,
            is_active=payload.is_active,
        )
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))
    except ValueError as e:
        raise _http_error(e)


@router.delete("/{series_id}", status_code=204)
async def delete_series(
    series_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Delete a series. Games it already produced survive as one-offs."""
    try:
        await series_service.delete_series(
            db, series_id=series_id, organiser_id=current_user.id
        )
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))
    except ValueError as e:
        raise _http_error(e)
