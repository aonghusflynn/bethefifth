import logging
import secrets
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Header, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from config import get_settings
from database import get_db
from schemas.series import TickResponse
from services.series import series_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/internal", tags=["internal"])


async def require_internal_key(x_internal_key: str | None = Header(None)) -> None:
    """Guard endpoints driven by cron rather than by a signed-in user.

    Deliberately fails closed: with no key configured the endpoint is disabled
    outright rather than left open, since it creates games and sends pushes.
    """
    settings = get_settings()

    if not settings.internal_api_key:
        raise HTTPException(
            status_code=503, detail="Internal endpoints are not configured."
        )

    if not x_internal_key or not secrets.compare_digest(
        x_internal_key, settings.internal_api_key
    ):
        raise HTTPException(status_code=403, detail="Invalid internal API key.")


@router.post("/tick", response_model=TickResponse)
async def tick(
    _: None = Depends(require_internal_key),
    db: AsyncSession = Depends(get_db),
):
    """Scheduler entry point — safe to call as often as you like.

    Materialises upcoming instances of every active series and invites their
    squads. Idempotent, so a missed or repeated run is harmless.

    Intended to be driven by an external cron at roughly 5-minute intervals,
    which is the granularity the marketplace auto-open in the next slice needs.
    """
    settings = get_settings()
    now = datetime.now(timezone.utc)

    created = await series_service.materialise_upcoming(
        db, now=now, horizon_days=settings.materialise_horizon_days
    )

    if created:
        logger.info("Tick materialised %d game(s)", len(created))

    return TickResponse(
        materialised=len(created), game_ids=[g.id for g in created]
    )
