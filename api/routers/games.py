import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.future import select
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from middleware.auth import get_current_user
from models.game import Game
from models.venue import Venue
from models.booking import Booking
from models.user import User
from schemas.game import GameCreate, GameListResponse, GameResponse, GameUpdate
from services.geo import bounding_box, haversine_distance
from services.marketplace import marketplace_service

router = APIRouter(prefix="/games", tags=["games"])


@router.get("/", response_model=GameListResponse)
@router.get("", response_model=GameListResponse)
async def list_games(
    lat: float | None = Query(None, ge=-90, le=90),
    lng: float | None = Query(None, ge=-180, le=180),
    radius_km: float = Query(10.0, ge=0.1, le=100),
    skill_level: int | None = Query(None, ge=1, le=5),
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
):
    """List open games, optionally filtered by location and skill level."""
    query = select(Game, Venue.lat, Venue.lng).join(Venue, Game.venue_id == Venue.id)

    # Apply bounding box pre-filter if location is provided
    if lat is not None and lng is not None:
        min_lat, max_lat, min_lng, max_lng = bounding_box(lat, lng, radius_km)
        query = query.where(
            Venue.lat.between(min_lat, max_lat),
            Venue.lng.between(min_lng, max_lng),
        )

    if skill_level is not None:
        query = query.where(Game.skill_level == skill_level)

    # Filter for active games (open/full). Squad-only games are deliberately
    # excluded — they reach the marketplace only once opened.
    query = query.where(
        Game.status.in_(["open", "full"]),
        Game.visibility == "public",
    )

    # Execute
    result = await db.execute(query)
    rows = result.all()

    # Precise Haversine distance filtering in Python
    filtered_games = []
    for game, v_lat, v_lng in rows:
        if lat is not None and lng is not None:
            dist = haversine_distance(lat, lng, v_lat, v_lng)
            if dist <= radius_km:
                filtered_games.append(game)
        else:
            filtered_games.append(game)

    # Sort by starts_at
    filtered_games.sort(key=lambda g: g.starts_at)

    total = len(filtered_games)
    start_idx = (page - 1) * per_page
    end_idx = start_idx + per_page
    paginated_games = filtered_games[start_idx:end_idx]

    return GameListResponse(
        items=paginated_games,
        total=total,
        page=page,
        per_page=per_page,
    )


@router.post("/", response_model=GameResponse, status_code=201)
@router.post("", response_model=GameResponse, status_code=201)
async def create_game(
    game: GameCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Create a new game."""
    # Verify venue exists
    venue_result = await db.execute(select(Venue).where(Venue.id == game.venue_id))
    venue = venue_result.scalar_one_or_none()
    if not venue:
        raise HTTPException(status_code=404, detail="Venue not found.")

    new_game = Game(
        organiser_id=current_user.id,
        venue_id=game.venue_id,
        title=game.title,
        description=game.description,
        starts_at=game.starts_at,
        duration_minutes=game.duration_minutes,
        max_players=game.max_players,
        skill_level=game.skill_level,
        is_private=game.is_private,
        visibility=game.visibility,
        status="open",
    )
    db.add(new_game)
    await db.commit()
    await db.refresh(new_game)
    return new_game


@router.get("/{game_id}", response_model=GameResponse)
async def get_game(game_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    """Get game details by ID."""
    result = await db.execute(select(Game).where(Game.id == game_id))
    game = result.scalar_one_or_none()
    if not game:
        raise HTTPException(status_code=404, detail="Game not found.")
    return game


@router.patch("/{game_id}", response_model=GameResponse)
async def update_game(
    game_id: uuid.UUID,
    game_update: GameUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Update game details (organiser only)."""
    result = await db.execute(select(Game).where(Game.id == game_id))
    game = result.scalar_one_or_none()
    if not game:
        raise HTTPException(status_code=404, detail="Game not found.")

    if game.organiser_id != current_user.id:
        raise HTTPException(status_code=403, detail="You are not authorized to update this game.")

    update_data = game_update.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(game, key, value)

    await db.commit()
    await db.refresh(game)
    return game


@router.post("/{game_id}/marketplace", response_model=GameResponse)
async def open_to_marketplace(
    game_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Open a squad-only game to the marketplace immediately.

    Otherwise this happens automatically if the game is still short close to
    kick-off, but an organiser who already knows they're light shouldn't have
    to wait for that.
    """
    try:
        return await marketplace_service.open_manually(
            db,
            game_id=game_id,
            organiser_id=current_user.id,
            now=datetime.now(timezone.utc),
        )
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.delete("/{game_id}/marketplace", response_model=GameResponse)
async def close_to_marketplace(
    game_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Take a game back off the marketplace.

    Refused once someone outside the squad has claimed a slot.
    """
    try:
        return await marketplace_service.close_manually(
            db, game_id=game_id, organiser_id=current_user.id
        )
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))
    except ValueError as e:
        detail = str(e)
        status_code = 404 if "not found" in detail.lower() else 409
        raise HTTPException(status_code=status_code, detail=detail)


@router.delete("/{game_id}", status_code=204)
async def delete_game(
    game_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Cancel/delete a game (organiser only)."""
    result = await db.execute(select(Game).where(Game.id == game_id))
    game = result.scalar_one_or_none()
    if not game:
        raise HTTPException(status_code=404, detail="Game not found.")

    if game.organiser_id != current_user.id:
        raise HTTPException(status_code=403, detail="You are not authorized to cancel this game.")

    # Cancel the game
    game.status = "cancelled"

    # Find and cancel all active bookings
    bookings_result = await db.execute(
        select(Booking).where(
            Booking.game_id == game.id,
            Booking.status.in_(["confirmed", "waitlisted"]),
        )
    )
    bookings = bookings_result.scalars().all()

    # Send push notifications
    player_ids = [str(b.player_id) for b in bookings]
    if player_ids:
        from services.notifications import notification_service
        try:
            await notification_service.send_bulk(
                user_ids=player_ids,
                title=f"Game Cancelled: {game.title}",
                body=f"The match scheduled for {game.starts_at} has been cancelled by the organiser.",
                data={"game_id": str(game.id)},
            )
        except Exception:
            pass

    for b in bookings:
        b.status = "cancelled"

    await db.commit()
