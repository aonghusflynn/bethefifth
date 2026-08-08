from datetime import datetime, timezone

import pytest

from models.game import Game
from models.user import User
from models.venue import Venue

ORGANISER_AUTH = {"Authorization": "Bearer mock-token-organiser_uid"}
PLAYER_AUTH = {"Authorization": "Bearer mock-token-player_uid_0"}
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
    db.add_all([organiser, stranger])

    players = []
    for i in range(3):
        player = User(
            firebase_uid=f"player_uid_{i}",
            email=f"player{i}@example.com",
            display_name=f"Player {i}",
        )
        db.add(player)
        players.append(player)

    venue = Venue(
        name="Dublin Pitch",
        address="123 Main St",
        city="Dublin",
        lat=53.3498,
        lng=-6.2603,
    )
    db.add(venue)
    await db.flush()

    game = Game(
        organiser_id=organiser.id,
        venue_id=venue.id,
        title="Tuesday 5-a-side",
        starts_at=datetime.now(timezone.utc),
        duration_minutes=60,
        max_players=10,
        current_players=0,
        status="open",
    )
    db.add(game)
    await db.commit()
    await db.refresh(game)
    for u in (organiser, stranger, *players):
        await db.refresh(u)

    return {"organiser": organiser, "stranger": stranger, "players": players, "game": game}


@pytest.fixture
async def squad_id(client, setup):
    created = await client.post(
        "/api/v1/squads", json={"name": "Tuesday Regulars"}, headers=ORGANISER_AUTH
    )
    squad_id = created.json()["id"]
    for player in setup["players"]:
        await client.post(
            f"/api/v1/squads/{squad_id}/members",
            json={"display_name": player.display_name, "email": player.email},
            headers=ORGANISER_AUTH,
        )
    return squad_id


async def test_invite_squad_endpoint(client, setup, squad_id):
    game = setup["game"]

    response = await client.post(
        f"/api/v1/games/{game.id}/invitations",
        json={"squad_id": squad_id},
        headers=ORGANISER_AUTH,
    )

    assert response.status_code == 201
    body = response.json()
    assert len(body) == 3
    assert {b["status"] for b in body} == {"invited"}


async def test_non_organiser_cannot_invite(client, setup, squad_id):
    game = setup["game"]

    response = await client.post(
        f"/api/v1/games/{game.id}/invitations",
        json={"squad_id": squad_id},
        headers=STRANGER_AUTH,
    )

    assert response.status_code == 403


async def test_accept_invitation_endpoint(client, setup, squad_id):
    game = setup["game"]
    await client.post(
        f"/api/v1/games/{game.id}/invitations",
        json={"squad_id": squad_id},
        headers=ORGANISER_AUTH,
    )

    response = await client.post(
        f"/api/v1/games/{game.id}/attendance",
        json={"attending": True},
        headers=PLAYER_AUTH,
    )

    assert response.status_code == 200
    assert response.json()["status"] == "confirmed"


async def test_decline_invitation_endpoint(client, setup, squad_id):
    game = setup["game"]
    await client.post(
        f"/api/v1/games/{game.id}/invitations",
        json={"squad_id": squad_id},
        headers=ORGANISER_AUTH,
    )

    response = await client.post(
        f"/api/v1/games/{game.id}/attendance",
        json={"attending": False},
        headers=PLAYER_AUTH,
    )

    assert response.status_code == 200
    assert response.json()["status"] == "declined"


async def test_responding_without_invitation_returns_404(client, setup):
    game = setup["game"]

    response = await client.post(
        f"/api/v1/games/{game.id}/attendance",
        json={"attending": True},
        headers=STRANGER_AUTH,
    )

    assert response.status_code == 404


async def test_declined_booking_is_not_returned_as_active(client, setup, squad_id):
    """A declined player reads as 'not booked', so they can join again later."""
    game = setup["game"]
    await client.post(
        f"/api/v1/games/{game.id}/invitations",
        json={"squad_id": squad_id},
        headers=ORGANISER_AUTH,
    )
    await client.post(
        f"/api/v1/games/{game.id}/attendance",
        json={"attending": False},
        headers=PLAYER_AUTH,
    )

    response = await client.get(f"/api/v1/games/{game.id}/booking", headers=PLAYER_AUTH)

    assert response.status_code == 404


async def test_attendance_requires_auth(client, setup):
    game = setup["game"]

    response = await client.post(
        f"/api/v1/games/{game.id}/attendance", json={"attending": True}
    )

    assert response.status_code in (401, 403)
