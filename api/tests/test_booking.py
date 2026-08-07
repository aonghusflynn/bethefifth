import uuid
from datetime import datetime, timezone
import pytest
from sqlalchemy.future import select

from models.booking import Booking
from models.game import Game
from models.user import User
from models.venue import Venue
from services.booking import booking_service


@pytest.fixture
async def seed_data(db):
    # Create organiser
    organiser = User(
        firebase_uid="organiser_uid",
        email="organiser@example.com",
        display_name="Organiser",
        is_organiser=True,
    )
    db.add(organiser)

    # Create players
    players = []
    for i in range(12):
        player = User(
            firebase_uid=f"player_uid_{i}",
            email=f"player{i}@example.com",
            display_name=f"Player {i}",
        )
        db.add(player)
        players.append(player)

    # Create venue
    venue = Venue(
        name="Dublin Pitch",
        address="123 Main St",
        city="Dublin",
        lat=53.3498,
        lng=-6.2603,
    )
    db.add(venue)

    await db.flush()  # populate IDs

    # Create game with max 10 players
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

    # Refresh objects
    await db.refresh(game)
    await db.refresh(organiser)
    for p in players:
        await db.refresh(p)

    return {
        "organiser": organiser,
        "players": players,
        "venue": venue,
        "game": game,
    }


async def test_create_booking_confirmed(db, seed_data):
    game = seed_data["game"]
    player = seed_data["players"][0]

    booking = await booking_service.create_booking(db, game.id, player.id)

    assert booking.status == "confirmed"
    assert booking.player_id == player.id
    assert booking.game_id == game.id

    # Check game is updated
    await db.refresh(game)
    assert game.current_players == 1
    assert game.status == "open"


async def test_create_booking_waitlisted(db, seed_data):
    game = seed_data["game"]
    players = seed_data["players"]

    # Fill game to max (10 confirmed players)
    for i in range(10):
        await booking_service.create_booking(db, game.id, players[i].id)

    await db.refresh(game)
    assert game.current_players == 10
    assert game.status == "full"

    # 11th player should be waitlisted
    booking_11 = await booking_service.create_booking(db, game.id, players[10].id)
    assert booking_11.status == "waitlisted"

    await db.refresh(game)
    assert game.current_players == 10  # current players stays at 10
    assert game.status == "full"


async def test_create_duplicate_booking_raises_error(db, seed_data):
    game = seed_data["game"]
    player = seed_data["players"][0]

    await booking_service.create_booking(db, game.id, player.id)

    with pytest.raises(ValueError, match="already has a booking"):
        await booking_service.create_booking(db, game.id, player.id)


async def test_cancel_confirmed_booking_no_waitlist(db, seed_data):
    game = seed_data["game"]
    player = seed_data["players"][0]

    booking = await booking_service.create_booking(db, game.id, player.id)
    await db.refresh(game)
    assert game.current_players == 1

    cancelled_booking = await booking_service.cancel_booking(db, booking.id)
    assert cancelled_booking.status == "cancelled"

    await db.refresh(game)
    assert game.current_players == 0
    assert game.status == "open"


async def test_cancel_confirmed_booking_promotes_waitlist(db, seed_data):
    game = seed_data["game"]
    players = seed_data["players"]

    # Fill the game (10 confirmed players)
    bookings = []
    for i in range(10):
        b = await booking_service.create_booking(db, game.id, players[i].id)
        bookings.append(b)

    # Add 2 waitlisted players
    waitlisted_1 = await booking_service.create_booking(db, game.id, players[10].id)
    waitlisted_2 = await booking_service.create_booking(db, game.id, players[11].id)

    # Cancel one confirmed booking (e.g. the first one)
    await booking_service.cancel_booking(db, bookings[0].id)

    # The first waitlisted player should be promoted to confirmed
    await db.refresh(waitlisted_1)
    await db.refresh(waitlisted_2)
    assert waitlisted_1.status == "confirmed"
    assert waitlisted_2.status == "waitlisted"



    # Game should remain full
    await db.refresh(game)
    assert game.current_players == 10
    assert game.status == "full"


async def test_cancel_waitlisted_booking_does_not_promote_others(db, seed_data):
    game = seed_data["game"]
    players = seed_data["players"]

    # Fill the game (10 confirmed players)
    for i in range(10):
        await booking_service.create_booking(db, game.id, players[i].id)

    # Add 2 waitlisted players
    waitlisted_1 = await booking_service.create_booking(db, game.id, players[10].id)
    waitlisted_2 = await booking_service.create_booking(db, game.id, players[11].id)

    # Cancel the first waitlisted booking
    await booking_service.cancel_booking(db, waitlisted_1.id)

    # Waitlisted 1 should be cancelled
    await db.refresh(waitlisted_1)
    assert waitlisted_1.status == "cancelled"

    # Waitlisted 2 should remain waitlisted (not promoted)
    await db.refresh(waitlisted_2)
    assert waitlisted_2.status == "waitlisted"

    # Game should stay full
    await db.refresh(game)
    assert game.current_players == 10
    assert game.status == "full"
