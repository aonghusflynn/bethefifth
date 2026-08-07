import uuid
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from middleware.auth import get_current_user
from models.user import User
from models.venue import Venue
from schemas.venue import VenueCreate, VenueResponse

router = APIRouter(prefix="/venues", tags=["venues"])


@router.get("/", response_model=list[VenueResponse])
@router.get("", response_model=list[VenueResponse])
async def list_venues(
    city: str | None = Query(None),
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
):
    """List venues, optionally filtered by city."""
    query = select(Venue)
    if city:
        query = query.where(func.lower(Venue.city) == func.lower(city))

    # Paginate and order by name
    query = query.order_by(Venue.name.asc()).offset((page - 1) * per_page).limit(per_page)
    result = await db.execute(query)
    venues = result.scalars().all()
    return venues


@router.post("/", response_model=VenueResponse, status_code=201)
@router.post("", response_model=VenueResponse, status_code=201)
async def create_venue(
    venue_in: VenueCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Add a new venue."""
    new_venue = Venue(
        name=venue_in.name,
        address=venue_in.address,
        city=venue_in.city,
        country=venue_in.country,
        lat=venue_in.lat,
        lng=venue_in.lng,
        surface=venue_in.surface,
        pitch_size=venue_in.pitch_size,
        parking=venue_in.parking,
        created_by=current_user.id,
    )
    db.add(new_venue)
    await db.commit()
    await db.refresh(new_venue)
    return new_venue


@router.get("/{venue_id}", response_model=VenueResponse)
async def get_venue(
    venue_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
):
    """Get venue details by ID."""
    result = await db.execute(select(Venue).where(Venue.id == venue_id))
    venue = result.scalar_one_or_none()
    if venue is None:
        raise HTTPException(status_code=404, detail="Venue not found")
    return venue

