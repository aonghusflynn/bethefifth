from datetime import datetime, timedelta, timezone

import pytest

from config import get_settings
from models.user import User
from models.venue import Venue

ORGANISER_AUTH = {"Authorization": "Bearer mock-token-organiser_uid"}
STRANGER_AUTH = {"Authorization": "Bearer mock-token-stranger_uid"}
INTERNAL_KEY = "test-internal-key"


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


@pytest.fixture
def internal_key():
    """Enable the cron endpoints for the duration of a test."""
    settings = get_settings()
    original = settings.internal_api_key
    settings.internal_api_key = INTERNAL_KEY
    yield INTERNAL_KEY
    settings.internal_api_key = original


@pytest.fixture
def no_internal_key():
    """Force the unconfigured case.

    Set explicitly rather than assumed, so the test doesn't depend on whether
    a developer happens to have INTERNAL_API_KEY in their local .env.
    """
    settings = get_settings()
    original = settings.internal_api_key
    settings.internal_api_key = ""
    yield
    settings.internal_api_key = original


def series_payload(setup, **overrides):
    # Relative to now, so the tick's real-clock horizon always covers it.
    # Any 14-day window contains at least one Tuesday.
    starts_at = datetime.now(timezone.utc) + timedelta(days=1)
    payload = {
        "venue_id": str(setup["venue"].id),
        "title": "Tuesday Night 5s",
        "starts_at": starts_at.isoformat(),
        "rrule": "FREQ=WEEKLY;BYDAY=TU",
        "duration_minutes": 60,
        "max_players": 10,
        "skill_level": 3,
    }
    payload.update(overrides)
    return payload


async def test_create_series(client, setup):
    response = await client.post(
        "/api/v1/series", json=series_payload(setup), headers=ORGANISER_AUTH
    )

    assert response.status_code == 201
    body = response.json()
    assert body["title"] == "Tuesday Night 5s"
    assert body["is_active"] is True


async def test_create_series_rejects_bad_rrule(client, setup):
    response = await client.post(
        "/api/v1/series",
        json=series_payload(setup, rrule="TOTALLY-INVALID"),
        headers=ORGANISER_AUTH,
    )

    assert response.status_code == 400


async def test_cannot_attach_someone_elses_squad(client, setup):
    other_squad = await client.post(
        "/api/v1/squads", json={"name": "Not Yours"}, headers=STRANGER_AUTH
    )

    response = await client.post(
        "/api/v1/series",
        json=series_payload(setup, squad_id=other_squad.json()["id"]),
        headers=ORGANISER_AUTH,
    )

    assert response.status_code == 403


async def test_list_series_scoped_to_organiser(client, setup):
    await client.post(
        "/api/v1/series", json=series_payload(setup), headers=ORGANISER_AUTH
    )

    mine = await client.get("/api/v1/series", headers=ORGANISER_AUTH)
    theirs = await client.get("/api/v1/series", headers=STRANGER_AUTH)

    assert len(mine.json()) == 1
    assert theirs.json() == []


async def test_pause_series(client, setup):
    created = await client.post(
        "/api/v1/series", json=series_payload(setup), headers=ORGANISER_AUTH
    )
    series_id = created.json()["id"]

    response = await client.patch(
        f"/api/v1/series/{series_id}",
        json={"is_active": False},
        headers=ORGANISER_AUTH,
    )

    assert response.status_code == 200
    assert response.json()["is_active"] is False


async def test_non_organiser_cannot_pause_series(client, setup):
    created = await client.post(
        "/api/v1/series", json=series_payload(setup), headers=ORGANISER_AUTH
    )
    series_id = created.json()["id"]

    response = await client.patch(
        f"/api/v1/series/{series_id}",
        json={"is_active": False},
        headers=STRANGER_AUTH,
    )

    assert response.status_code == 403


async def test_tick_is_disabled_when_no_key_configured(
    client, setup, no_internal_key
):
    """Fails closed — an unconfigured deployment must not expose this."""
    response = await client.post(
        "/api/v1/internal/tick", headers={"X-Internal-Key": "anything"}
    )

    assert response.status_code == 503


async def test_tick_rejects_a_wrong_key(client, setup, internal_key):
    response = await client.post(
        "/api/v1/internal/tick", headers={"X-Internal-Key": "wrong-key"}
    )

    assert response.status_code == 403


async def test_tick_rejects_a_missing_key(client, setup, internal_key):
    response = await client.post("/api/v1/internal/tick")

    assert response.status_code == 403


async def test_tick_materialises_series_instances(client, setup, internal_key):
    await client.post(
        "/api/v1/series", json=series_payload(setup), headers=ORGANISER_AUTH
    )

    response = await client.post(
        "/api/v1/internal/tick", headers={"X-Internal-Key": internal_key}
    )

    assert response.status_code == 200
    body = response.json()
    assert body["materialised"] >= 1
    assert len(body["game_ids"]) == body["materialised"]


async def test_tick_is_idempotent(client, setup, internal_key):
    await client.post(
        "/api/v1/series", json=series_payload(setup), headers=ORGANISER_AUTH
    )

    first = await client.post(
        "/api/v1/internal/tick", headers={"X-Internal-Key": internal_key}
    )
    second = await client.post(
        "/api/v1/internal/tick", headers={"X-Internal-Key": internal_key}
    )

    assert first.json()["materialised"] >= 1
    assert second.json()["materialised"] == 0


async def test_materialised_games_appear_in_the_games_list(
    client, setup, internal_key
):
    await client.post(
        "/api/v1/series", json=series_payload(setup), headers=ORGANISER_AUTH
    )
    await client.post(
        "/api/v1/internal/tick", headers={"X-Internal-Key": internal_key}
    )

    games = await client.get("/api/v1/games", headers=ORGANISER_AUTH)

    assert games.status_code == 200
    items = games.json()["items"]
    assert len(items) >= 1
    assert all(g["is_recurring"] for g in items)
    assert all(g["series_id"] is not None for g in items)
