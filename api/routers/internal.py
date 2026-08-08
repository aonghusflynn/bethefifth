import logging
import secrets
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Header, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from config import get_settings
from database import get_db
from schemas.series import TickResponse
from services.marketplace import marketplace_service
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

    Runs three idempotent steps in order:
      1. materialise upcoming instances of active series and invite squads
      2. open still-short squad-only games to the marketplace (T-2h)
      3. push still-short public games to nearby players (T-1h)

    Each step is independently idempotent, so a missed or repeated run is
    harmless. Intended to be driven by an external cron at roughly 5-minute
    intervals — that granularity is what the T-2h and T-1h windows need.
    """
    settings = get_settings()
    now = datetime.now(timezone.utc)

    created = await series_service.materialise_upcoming(
        db, now=now, horizon_days=settings.materialise_horizon_days
    )
    opened = await marketplace_service.auto_open_due(db, now=now)
    notified = await marketplace_service.notify_due(db, now=now)

    if created or opened or notified:
        logger.info(
            "Tick: materialised=%d opened=%d notified=%d",
            len(created),
            len(opened),
            len(notified),
        )

    return TickResponse(
        materialised=len(created),
        game_ids=[g.id for g in created],
        marketplace_opened=len(opened),
        marketplace_notified=len(notified),
    )
