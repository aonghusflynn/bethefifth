from datetime import datetime, timedelta, timezone

import pytest

from models.user import User
from models.venue import Venue

ORGANISER_AUTH = {"Authorization": "Bearer mock-token-organiser_uid"}
STRANGER_AUTH = {"Authorization": "Bearer mock-token-stranger_uid"}


@pytest.fixture
async def setup(db):
    organiser = User(
        firebase_uid="organiser_uid",
        email="organiser@example.com",
        display_name="Organiser",
        is_organiser=True,
    )
    stranger = User(
        firebase_uid="stranger_uid",
        email="stranger@example.com",
        display_name="Stranger",
    )
    venue = Venue(
        name="Irishtown", address="Dublin 4", city="Dublin", lat=53.34, lng=-6.22
    )
    db.add_all([organiser, stranger, venue])
    await db.commit()
    for obj in (organiser, stranger, venue):
        await db.refresh(obj)
    return {"organiser": organiser, "stranger": stranger, "venue": venue}


async def create_game(client, setup, visibility="squad_only"):
    starts_at = datetime.now(timezone.utc) + timedelta(days=3)
    response = await client.post(
        "/api/v1/games",
        json={
            "venue_id": str(setup["venue"].id),
            "title": "Tuesday Night 5s",
            "starts_at": starts_at.isoformat(),
            "duration_minutes": 60,
            "max_players": 10,
            "skill_level": 3,
            "visibility": visibility,
        },
        headers=ORGANISER_AUTH,
    )
    assert response.status_code == 201
    return response.json()


async def test_squad_only_game_is_hidden_from_the_marketplace(client, setup):
    await create_game(client, setup, visibility="squad_only")

    listing = await client.get("/api/v1/games", headers=STRANGER_AUTH)

    assert listing.json()["items"] == []


async def test_public_game_appears_in_the_marketplace(client, setup):
    game = await create_game(client, setup, visibility="public")

    listing = await client.get("/api/v1/games", headers=STRANGER_AUTH)

    assert [g["id"] for g in listing.json()["items"]] == [game["id"]]


async def test_organiser_can_open_a_game_to_the_marketplace(client, setup):
    game = await create_game(client, setup, visibility="squad_only")

    response = await client.post(
        f"/api/v1/games/{game['id']}/marketplace", headers=ORGANISER_AUTH
    )

    assert response.status_code == 200
    assert response.json()["visibility"] == "public"

    listing = await client.get("/api/v1/games", headers=STRANGER_AUTH)
    assert len(listing.json()["items"]) == 1


async def test_non_organiser_cannot_open_a_game(client, setup):
    game = await create_game(client, setup, visibility="squad_only")

    response = await client.post(
        f"/api/v1/games/{game['id']}/marketplace", headers=STRANGER_AUTH
    )

    assert response.status_code == 403


async def test_organiser_can_close_before_anyone_joins(client, setup):
    game = await create_game(client, setup, visibility="squad_only")
    await client.post(
        f"/api/v1/games/{game['id']}/marketplace", headers=ORGANISER_AUTH
    )

    response = await client.delete(
        f"/api/v1/games/{game['id']}/marketplace", headers=ORGANISER_AUTH
    )

    assert response.status_code == 200
    assert response.json()["visibility"] == "squad_only"

    listing = await client.get("/api/v1/games", headers=STRANGER_AUTH)
    assert listing.json()["items"] == []


async def test_closing_conflicts_once_an_outsider_joined(client, setup):
    game = await create_game(client, setup, visibility="squad_only")
    await client.post(
        f"/api/v1/games/{game['id']}/marketplace", headers=ORGANISER_AUTH
    )
    joined = await client.post(
        f"/api/v1/games/{game['id']}/bookings", headers=STRANGER_AUTH
    )
    assert joined.status_code == 201

    response = await client.delete(
        f"/api/v1/games/{game['id']}/marketplace", headers=ORGANISER_AUTH
    )

    assert response.status_code == 409


async def test_opening_is_idempotent(client, setup):
    game = await create_game(client, setup, visibility="squad_only")

    first = await client.post(
        f"/api/v1/games/{game['id']}/marketplace", headers=ORGANISER_AUTH
    )
    second = await client.post(
        f"/api/v1/games/{game['id']}/marketplace", headers=ORGANISER_AUTH
    )

    assert first.json()["visibility"] == "public"
    assert second.status_code == 200
    assert second.json()["visibility"] == "public"


async def test_open_unknown_game_returns_404(client, setup):
    missing = "00000000-0000-0000-0000-0000000000ff"

    response = await client.post(
        f"/api/v1/games/{missing}/marketplace", headers=ORGANISER_AUTH
    )

    assert response.status_code == 404
