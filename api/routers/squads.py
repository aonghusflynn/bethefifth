import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from middleware.auth import get_current_user
from models.user import User
from schemas.squad import (
    SquadCreate,
    SquadDetailResponse,
    SquadMemberCreate,
    SquadMemberResponse,
    SquadResponse,
    SquadUpdate,
)
from services.squad import squad_service

router = APIRouter(prefix="/squads", tags=["squads"])


def _not_found_or_bad_request(exc: ValueError) -> HTTPException:
    """Map service-layer ValueErrors onto the right status code."""
    detail = str(exc)
    status_code = 404 if "not found" in detail.lower() else 400
    return HTTPException(status_code=status_code, detail=detail)


@router.post("/", response_model=SquadResponse, status_code=201)
@router.post("", response_model=SquadResponse, status_code=201)
async def create_squad(
    payload: SquadCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Create a squad owned by the current user."""
    return await squad_service.create_squad(
        db, organiser_id=current_user.id, name=payload.name
    )


@router.get("/", response_model=list[SquadResponse])
@router.get("", response_model=list[SquadResponse])
async def list_squads(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """List the squads the current user organises, with member counts."""
    squads = await squad_service.list_squads(db, organiser_id=current_user.id)
    counts = await squad_service.member_counts(db, [s.id for s in squads])

    return [
        SquadResponse(
            id=s.id,
            organiser_id=s.organiser_id,
            name=s.name,
            created_at=s.created_at,
            active_member_count=counts.get(s.id, (0, 0))[0],
            pending_member_count=counts.get(s.id, (0, 0))[1],
        )
        for s in squads
    ]


@router.get("/{squad_id}", response_model=SquadDetailResponse)
async def get_squad(
    squad_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get a squad and its members."""
    squad = await squad_service.get_squad(db, squad_id)
    if squad is None:
        raise HTTPException(status_code=404, detail="Squad not found.")
    if squad.organiser_id != current_user.id:
        raise HTTPException(
            status_code=403, detail="Only the squad organiser can view it."
        )

    members = await squad_service.list_members(db, squad_id=squad_id)
    return SquadDetailResponse(
        id=squad.id,
        organiser_id=squad.organiser_id,
        name=squad.name,
        created_at=squad.created_at,
        active_member_count=sum(1 for m in members if m.user_id is not None),
        pending_member_count=sum(1 for m in members if m.user_id is None),
        members=[SquadMemberResponse.model_validate(m) for m in members],
    )


@router.patch("/{squad_id}", response_model=SquadResponse)
async def update_squad(
    squad_id: uuid.UUID,
    payload: SquadUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Rename a squad."""
    try:
        return await squad_service.rename_squad(
            db, squad_id=squad_id, organiser_id=current_user.id, name=payload.name
        )
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))
    except ValueError as e:
        raise _not_found_or_bad_request(e)


@router.delete("/{squad_id}", status_code=204)
async def delete_squad(
    squad_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Delete a squad and all of its memberships."""
    try:
        await squad_service.delete_squad(
            db, squad_id=squad_id, organiser_id=current_user.id
        )
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))
    except ValueError as e:
        raise _not_found_or_bad_request(e)


@router.post(
    "/{squad_id}/members", response_model=SquadMemberResponse, status_code=201
)
async def add_member(
    squad_id: uuid.UUID,
    payload: SquadMemberCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Add a player to a squad.

    If the email matches an existing account the member is active immediately;
    otherwise they are invited by email and linked when they register.
    """
    try:
        return await squad_service.add_member(
            db,
            squad_id=squad_id,
            organiser_id=current_user.id,
            display_name=payload.display_name,
            email=payload.email,
            phone=payload.phone,
        )
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))
    except ValueError as e:
        raise _not_found_or_bad_request(e)


@router.delete("/{squad_id}/members/{member_id}", status_code=204)
async def remove_member(
    squad_id: uuid.UUID,
    member_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Remove a player from a squad."""
    try:
        await squad_service.remove_member(
            db, squad_id=squad_id, member_id=member_id, organiser_id=current_user.id
        )
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))
    except ValueError as e:
        raise _not_found_or_bad_request(e)
