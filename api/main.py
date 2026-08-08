from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from config import get_settings
from routers import auth, bookings, games, internal, series, squads, users, venues
from services.firebase import firebase_service

import uuid
from sqlalchemy import select
from database import async_session
from models.venue import Venue

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    firebase_service.init_app()
    
    # Auto-seed fallback venues if database is empty
    async with async_session() as session:
        result = await session.execute(select(Venue))
        if not result.scalars().first():
            venues_to_seed = [
                Venue(
                    id=uuid.UUID("00000000-0000-0000-0000-000000000001"),
                    name="Irishtown Stadium (4G)",
                    address="Ringsend, Dublin 4",
                    city="Dublin",
                    lat=53.3412,
                    lng=-6.2201,
                    surface="4G Astro",
                ),
                Venue(
                    id=uuid.UUID("00000000-0000-0000-0000-000000000002"),
                    name="Sandymount YMCA",
                    address="Sandymount Road, Dublin 4",
                    city="Dublin",
                    lat=53.3321,
                    lng=-6.2185,
                    surface="3G Astro",
                ),
                Venue(
                    id=uuid.UUID("00000000-0000-0000-0000-000000000003"),
                    name="Herbert Park Pitch",
                    address="Herbert Park, Ballsbridge",
                    city="Dublin",
                    lat=53.3256,
                    lng=-6.2341,
                    surface="All-Weather Astro",
                ),
                Venue(
                    id=uuid.UUID("00000000-0000-0000-0000-000000000004"),
                    name="Ringsend Park Pitch",
                    address="Ringsend Park, Dublin 4",
                    city="Dublin",
                    lat=53.3401,
                    lng=-6.2112,
                    surface="4G Astro",
                ),
            ]
            session.add_all(venues_to_seed)
            await session.commit()
            
    yield


app = FastAPI(
    title="BeTheFifth API",
    version="0.1.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount routers under /api/v1
app.include_router(auth.router, prefix="/api/v1")
app.include_router(games.router, prefix="/api/v1")
app.include_router(bookings.router, prefix="/api/v1")
app.include_router(venues.router, prefix="/api/v1")
app.include_router(users.router, prefix="/api/v1")
app.include_router(squads.router, prefix="/api/v1")
app.include_router(series.router, prefix="/api/v1")
app.include_router(internal.router, prefix="/api/v1")


@app.get("/api/v1/health")
async def health():
    return {"status": "ok"}


@app.exception_handler(NotImplementedError)
async def not_implemented_handler(request: Request, exc: NotImplementedError):
    return JSONResponse(
        status_code=501,
        content={
            "type": "about:blank",
            "title": "Not Implemented",
            "status": 501,
            "detail": "This endpoint is not yet implemented.",
        },
    )
