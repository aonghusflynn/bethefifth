import uuid
from datetime import datetime, timezone
import pytest
from httpx import AsyncClient

from main import app
from middleware.auth import get_current_user, get_firebase_user_claims
from models.game import Game
from models.user import User
from models.venue import Venue
from models.booking import Booking


@pytest.fixture
async def seed_api_data(db):
    # Organiser
    organiser = User(
        firebase_uid="organiser_uid",
        email="organiser@example.com",
        display_name="Organiser",
        is_organiser=True,
    )
    db.add(organiser)

    # Player
    player = User(
        firebase_uid="player_uid",
        email="player@example.com",
        display_name="Player",
    )
    db.add(player)

    # Another player
    other_player = User(
        firebase_uid="other_uid",
        email="other@example.com",
        display_name="Other Player",
    )
    db.add(other_player)

    # Dublin Venue
    dublin_venue = Venue(
        name="Dublin Pitch",
        address="123 Main St",
        city="Dublin",
        lat=53.3498,
        lng=-6.2603,
    )
    db.add(dublin_venue)

    # Cork Venue
    cork_venue = Venue(
        name="Cork Pitch",
        address="456 Grand Parade",
        city="Cork",
        lat=51.8985,
        lng=-8.4756,
    )
    db.add(cork_venue)

    await db.flush()

    # Dublin Game
    dublin_game = Game(
        organiser_id=organiser.id,
        venue_id=dublin_venue.id,
        title="Dublin 5-a-side",
        starts_at=datetime.now(timezone.utc),
        duration_minutes=60,
        max_players=10,
        current_players=0,
        status="open",
    )
    db.add(dublin_game)

    # Cork Game
    cork_game = Game(
        organiser_id=organiser.id,
        venue_id=cork_venue.id,
        title="Cork 5-a-side",
        starts_at=datetime.now(timezone.utc),
        duration_minutes=60,
        max_players=10,
        current_players=0,
        status="open",
    )
    db.add(cork_game)

    await db.commit()
    await db.refresh(organiser)
    await db.refresh(player)
    await db.refresh(other_player)
    await db.refresh(dublin_game)
    await db.refresh(cork_game)

    return {
        "organiser": organiser,
        "player": player,
        "other_player": other_player,
        "dublin_venue": dublin_venue,
        "cork_venue": cork_venue,
        "dublin_game": dublin_game,
        "cork_game": cork_game,
    }


async def test_list_games_no_filters(client, seed_api_data):
    response = await client.get("/api/v1/games/")
    assert response.status_code == 200
    data = response.json()
    assert data["total"] == 2
    assert len(data["items"]) == 2
    assert data["items"][0]["title"] == "Dublin 5-a-side"
    assert data["items"][1]["title"] == "Cork 5-a-side"


async def test_list_games_geo_filter_dublin(client, seed_api_data):
    # Filter for Dublin location (within 20km)
    response = await client.get("/api/v1/games/?lat=53.3498&lng=-6.2603&radius_km=20")
    assert response.status_code == 200
    data = response.json()
    assert data["total"] == 1
    assert len(data["items"]) == 1
    assert data["items"][0]["title"] == "Dublin 5-a-side"


async def test_list_games_skill_filter(client, seed_api_data):
    response = await client.get("/api/v1/games/?skill_level=3")
    assert response.status_code == 200
    data = response.json()
    assert data["total"] == 2


async def test_create_game_unauthenticated(client, seed_api_data):
    game_data = {
        "venue_id": str(seed_api_data["dublin_venue"].id),
        "title": "New Friday Game",
        "starts_at": datetime.now(timezone.utc).isoformat(),
        "duration_minutes": 90,
        "max_players": 12,
        "skill_level": 4,
    }
    response = await client.post("/api/v1/games/", json=game_data)
    # No Auth header -> 401
    assert response.status_code == 401


async def test_create_game_authenticated(client, seed_api_data):
    organiser = seed_api_data["organiser"]
    venue = seed_api_data["dublin_venue"]

    async def mock_get_current_user():
        return organiser

    app.dependency_overrides[get_current_user] = mock_get_current_user

    game_data = {
        "venue_id": str(venue.id),
        "title": "New Friday Game",
        "starts_at": datetime.now(timezone.utc).isoformat(),
        "duration_minutes": 90,
        "max_players": 12,
        "skill_level": 4,
    }
    response = await client.post(
        "/api/v1/games/",
        json=game_data,
        headers={"Authorization": "Bearer some-token"},
    )
    assert response.status_code == 201
    data = response.json()
    assert data["title"] == "New Friday Game"
    assert data["max_players"] == 12
    assert data["organiser_id"] == str(organiser.id)
    assert data["venue_id"] == str(venue.id)

    app.dependency_overrides.clear()


async def test_get_game_details(client, seed_api_data):
    game = seed_api_data["dublin_game"]
    response = await client.get(f"/api/v1/games/{game.id}")
    assert response.status_code == 200
    data = response.json()
    assert data["title"] == "Dublin 5-a-side"


async def test_create_booking_authenticated(client, seed_api_data):
    player = seed_api_data["player"]
    game = seed_api_data["dublin_game"]

    async def mock_get_current_user():
        return player

    app.dependency_overrides[get_current_user] = mock_get_current_user

    response = await client.post(
        f"/api/v1/games/{game.id}/bookings",
        headers={"Authorization": "Bearer some-token"},
    )
    assert response.status_code == 201
    data = response.json()
    assert data["player_id"] == str(player.id)
    assert data["game_id"] == str(game.id)
    assert data["status"] == "confirmed"

    app.dependency_overrides.clear()


async def test_cancel_booking_authenticated(client, seed_api_data, db):
    player = seed_api_data["player"]
    game = seed_api_data["dublin_game"]

    # Create direct booking
    booking = Booking(game_id=game.id, player_id=player.id, status="confirmed")
    db.add(booking)
    game.current_players = 1
    await db.commit()

    async def mock_get_current_user():
        return player

    app.dependency_overrides[get_current_user] = mock_get_current_user

    response = await client.delete(
        f"/api/v1/bookings/{booking.id}",
        headers={"Authorization": "Bearer some-token"},
    )
    assert response.status_code == 204

    # Check database status
    await db.refresh(booking)
    assert booking.status == "cancelled"

    app.dependency_overrides.clear()


async def test_cancel_booking_unauthorized(client, seed_api_data, db):
    player = seed_api_data["player"]
    other_player = seed_api_data["other_player"]
    game = seed_api_data["dublin_game"]

    # Create direct booking for first player
    booking = Booking(game_id=game.id, player_id=player.id, status="confirmed")
    db.add(booking)
    await db.commit()

    # Authenticate as other_player
    async def mock_get_current_user():
        return other_player

    app.dependency_overrides[get_current_user] = mock_get_current_user

    # Attempt to cancel other player's booking
    response = await client.delete(
        f"/api/v1/bookings/{booking.id}",
        headers={"Authorization": "Bearer some-token"},
    )
    assert response.status_code == 403

    app.dependency_overrides.clear()


async def test_auth_register(client, db):
    # Mock firebase claims
    async def mock_get_firebase_user_claims():
        return {
            "uid": "new_firebase_uid",
            "email": "new_user@example.com",
            "name": "New User",
            "picture": "http://example.com/pic.png",
        }

    app.dependency_overrides[get_firebase_user_claims] = mock_get_firebase_user_claims

    response = await client.post(
        "/api/v1/auth/register",
        headers={"Authorization": "Bearer some-token"}
    )
    assert response.status_code == 201
    data = response.json()
    assert data["firebase_uid"] == "new_firebase_uid"
    assert data["email"] == "new_user@example.com"
    assert data["display_name"] == "New User"
    assert data["photo_url"] == "http://example.com/pic.png"

    app.dependency_overrides.clear()


async def test_auth_login(client, seed_api_data):
    player = seed_api_data["player"]

    async def mock_get_current_user():
        return player

    app.dependency_overrides[get_current_user] = mock_get_current_user

    response = await client.post(
        "/api/v1/auth/login",
        headers={"Authorization": "Bearer some-token"}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == str(player.id)
    assert data["firebase_uid"] == player.firebase_uid

    app.dependency_overrides.clear()


async def test_get_current_user_profile(client, seed_api_data):
    player = seed_api_data["player"]

    async def mock_get_current_user():
        return player

    app.dependency_overrides[get_current_user] = mock_get_current_user

    response = await client.get(
        "/api/v1/users/me",
        headers={"Authorization": "Bearer some-token"}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == str(player.id)
    assert data["display_name"] == "Player"

    app.dependency_overrides.clear()


async def test_update_current_user_profile(client, seed_api_data):
    player = seed_api_data["player"]

    async def mock_get_current_user():
        return player

    app.dependency_overrides[get_current_user] = mock_get_current_user

    update_payload = {
        "display_name": "Updated Player",
        "position": "midfielder",
        "skill_level": 4,
    }
    response = await client.patch(
        "/api/v1/users/me",
        json=update_payload,
        headers={"Authorization": "Bearer some-token"}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["display_name"] == "Updated Player"
    assert data["position"] == "midfielder"
    assert data["skill_level"] == 4

    app.dependency_overrides.clear()


async def test_get_user_games(client, seed_api_data, db):
    player = seed_api_data["player"]
    game = seed_api_data["dublin_game"]

    # Book the player
    booking = Booking(game_id=game.id, player_id=player.id, status="confirmed")
    db.add(booking)
    await db.commit()

    response = await client.get(f"/api/v1/users/{player.id}/games")
    assert response.status_code == 200
    data = response.json()
    assert data["total"] == 1
    assert data["items"][0]["id"] == str(game.id)


async def test_list_venues(client, seed_api_data):
    response = await client.get("/api/v1/venues/")
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 2
    # Verify sorted alphabetically by name
    assert data[0]["name"] == "Cork Pitch"
    assert data[1]["name"] == "Dublin Pitch"


async def test_list_venues_filter_city(client, seed_api_data):
    response = await client.get("/api/v1/venues/?city=Dublin")
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 1
    assert data[0]["city"] == "Dublin"


async def test_create_venue(client, seed_api_data):
    organiser = seed_api_data["organiser"]

    async def mock_get_current_user():
        return organiser

    app.dependency_overrides[get_current_user] = mock_get_current_user

    venue_payload = {
        "name": "Irishtown Stadium",
        "address": "Ringsend, Dublin 4",
        "city": "Dublin",
        "lat": 53.3412,
        "lng": -6.2201,
        "surface": "astro",
        "pitch_size": "5-a-side",
        "parking": True,
    }
    response = await client.post(
        "/api/v1/venues/",
        json=venue_payload,
        headers={"Authorization": "Bearer some-token"}
    )
    assert response.status_code == 201
    data = response.json()
    assert data["name"] == "Irishtown Stadium"
    assert data["city"] == "Dublin"
    assert data["surface"] == "astro"

    app.dependency_overrides.clear()


async def test_get_venue_details(client, seed_api_data):
    venue = seed_api_data["dublin_venue"]
    response = await client.get(f"/api/v1/venues/{venue.id}")
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "Dublin Pitch"


async def test_get_my_booking_authenticated(client, seed_api_data, db):
    player = seed_api_data["player"]
    game = seed_api_data["dublin_game"]

    # Seed booking
    booking = Booking(game_id=game.id, player_id=player.id, status="confirmed")
    db.add(booking)
    await db.commit()

    async def mock_get_current_user():
        return player

    app.dependency_overrides[get_current_user] = mock_get_current_user

    response = await client.get(
        f"/api/v1/games/{game.id}/booking",
        headers={"Authorization": "Bearer some-token"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == str(booking.id)
    assert data["status"] == "confirmed"

    # Test 404 if no booking exists
    other_game = seed_api_data["cork_game"]
    response_404 = await client.get(
        f"/api/v1/games/{other_game.id}/booking",
        headers={"Authorization": "Bearer some-token"},
    )
    assert response_404.status_code == 404

    app.dependency_overrides.clear()


