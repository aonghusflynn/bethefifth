import uuid
from datetime import datetime, timezone

import pytest

from models.booking import Booking
from models.game import Game
from models.user import User
from models.venue import Venue
from services.booking import booking_service
from services.squad import squad_service


@pytest.fixture
async def setup(db):
    """An organiser with a 12-strong squad and a 10-slot game."""
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
    for i in range(12):
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
    await db.refresh(organiser)
    await db.refresh(stranger)
    for p in players:
        await db.refresh(p)

    # A squad containing all 12 players, plus one friend with no account yet.
    squad = await squad_service.create_squad(
        db, organiser_id=organiser.id, name="Tuesday Regulars"
    )
    for p in players:
        await squad_service.add_member(
            db,
            squad_id=squad.id,
            organiser_id=organiser.id,
            display_name=p.display_name,
            email=p.email,
        )
    await squad_service.add_member(
        db,
        squad_id=squad.id,
        organiser_id=organiser.id,
        display_name="Barry From Work",
        email="barry@example.com",
    )

    return {
        "organiser": organiser,
        "stranger": stranger,
        "players": players,
        "game": game,
        "squad": squad,
    }


async def test_invite_squad_creates_invited_bookings(db, setup):
    game, squad, organiser = setup["game"], setup["squad"], setup["organiser"]

    invited = await booking_service.invite_squad(
        db, game_id=game.id, squad_id=squad.id, organiser_id=organiser.id
    )

    # 12 registered members invited; the unregistered friend is skipped.
    assert len(invited) == 12
    assert all(b.status == "invited" for b in invited)


async def test_invitations_do_not_consume_slots(db, setup):
    game, squad, organiser = setup["game"], setup["squad"], setup["organiser"]

    await booking_service.invite_squad(
        db, game_id=game.id, squad_id=squad.id, organiser_id=organiser.id
    )

    await db.refresh(game)
    assert game.current_players == 0
    assert game.status == "open"


async def test_accepting_an_invitation_confirms_and_takes_a_slot(db, setup):
    game, squad, organiser = setup["game"], setup["squad"], setup["organiser"]
    player = setup["players"][0]

    await booking_service.invite_squad(
        db, game_id=game.id, squad_id=squad.id, organiser_id=organiser.id
    )

    booking = await booking_service.respond_to_invitation(
        db, game_id=game.id, player_id=player.id, attending=True
    )

    assert booking.status == "confirmed"
    await db.refresh(game)
    assert game.current_players == 1


async def test_declining_an_invitation_takes_no_slot(db, setup):
    game, squad, organiser = setup["game"], setup["squad"], setup["organiser"]
    player = setup["players"][0]

    await booking_service.invite_squad(
        db, game_id=game.id, squad_id=squad.id, organiser_id=organiser.id
    )

    booking = await booking_service.respond_to_invitation(
        db, game_id=game.id, player_id=player.id, attending=False
    )

    assert booking.status == "declined"
    await db.refresh(game)
    assert game.current_players == 0


async def test_first_come_first_served_fills_slots_in_order(db, setup):
    """The whole point of a squad bigger than the game: first 10 to accept play."""
    game, squad, organiser = setup["game"], setup["squad"], setup["organiser"]
    players = setup["players"]

    await booking_service.invite_squad(
        db, game_id=game.id, squad_id=squad.id, organiser_id=organiser.id
    )

    accepted = []
    for p in players:  # all 12 accept, in order
        accepted.append(
            await booking_service.respond_to_invitation(
                db, game_id=game.id, player_id=p.id, attending=True
            )
        )

    assert [b.status for b in accepted[:10]] == ["confirmed"] * 10
    assert [b.status for b in accepted[10:]] == ["waitlisted"] * 2

    await db.refresh(game)
    assert game.current_players == 10
    assert game.status == "full"


async def test_declining_after_confirming_frees_slot_and_promotes_waitlist(db, setup):
    game, squad, organiser = setup["game"], setup["squad"], setup["organiser"]
    players = setup["players"]

    await booking_service.invite_squad(
        db, game_id=game.id, squad_id=squad.id, organiser_id=organiser.id
    )
    for p in players[:11]:
        await booking_service.respond_to_invitation(
            db, game_id=game.id, player_id=p.id, attending=True
        )

    # Player 10 accepted 11th, so is waitlisted.
    waitlisted = await booking_service.get_player_booking(
        db, game_id=game.id, player_id=players[10].id
    )
    assert waitlisted.status == "waitlisted"

    # Someone who was confirmed now pulls out.
    await booking_service.respond_to_invitation(
        db, game_id=game.id, player_id=players[0].id, attending=False
    )

    await db.refresh(waitlisted)
    assert waitlisted.status == "confirmed"

    await db.refresh(game)
    assert game.current_players == 10


async def test_changing_mind_from_declined_to_attending(db, setup):
    game, squad, organiser = setup["game"], setup["squad"], setup["organiser"]
    player = setup["players"][0]

    await booking_service.invite_squad(
        db, game_id=game.id, squad_id=squad.id, organiser_id=organiser.id
    )
    await booking_service.respond_to_invitation(
        db, game_id=game.id, player_id=player.id, attending=False
    )

    booking = await booking_service.respond_to_invitation(
        db, game_id=game.id, player_id=player.id, attending=True
    )

    assert booking.status == "confirmed"
    await db.refresh(game)
    assert game.current_players == 1


async def test_accepting_twice_is_idempotent(db, setup):
    game, squad, organiser = setup["game"], setup["squad"], setup["organiser"]
    player = setup["players"][0]

    await booking_service.invite_squad(
        db, game_id=game.id, squad_id=squad.id, organiser_id=organiser.id
    )
    await booking_service.respond_to_invitation(
        db, game_id=game.id, player_id=player.id, attending=True
    )
    await booking_service.respond_to_invitation(
        db, game_id=game.id, player_id=player.id, attending=True
    )

    await db.refresh(game)
    assert game.current_players == 1  # not 2


async def test_responding_without_an_invitation_raises(db, setup):
    game = setup["game"]
    stranger = setup["stranger"]

    with pytest.raises(ValueError, match="Invitation not found"):
        await booking_service.respond_to_invitation(
            db, game_id=game.id, player_id=stranger.id, attending=True
        )


async def test_inviting_twice_does_not_duplicate(db, setup):
    game, squad, organiser = setup["game"], setup["squad"], setup["organiser"]

    first = await booking_service.invite_squad(
        db, game_id=game.id, squad_id=squad.id, organiser_id=organiser.id
    )
    second = await booking_service.invite_squad(
        db, game_id=game.id, squad_id=squad.id, organiser_id=organiser.id
    )

    assert len(first) == 12
    assert second == []  # everyone already has a booking


async def test_reinviting_does_not_reset_an_existing_response(db, setup):
    game, squad, organiser = setup["game"], setup["squad"], setup["organiser"]
    player = setup["players"][0]

    await booking_service.invite_squad(
        db, game_id=game.id, squad_id=squad.id, organiser_id=organiser.id
    )
    await booking_service.respond_to_invitation(
        db, game_id=game.id, player_id=player.id, attending=True
    )

    await booking_service.invite_squad(
        db, game_id=game.id, squad_id=squad.id, organiser_id=organiser.id
    )

    booking = await booking_service.get_player_booking(
        db, game_id=game.id, player_id=player.id
    )
    assert booking.status == "confirmed"


async def test_non_organiser_cannot_invite(db, setup):
    game, squad = setup["game"], setup["squad"]
    stranger = setup["stranger"]

    with pytest.raises(PermissionError):
        await booking_service.invite_squad(
            db, game_id=game.id, squad_id=squad.id, organiser_id=stranger.id
        )


async def test_cannot_invite_a_squad_you_do_not_own(db, setup):
    game, organiser = setup["game"], setup["organiser"]
    stranger = setup["stranger"]

    other_squad = await squad_service.create_squad(
        db, organiser_id=stranger.id, name="Someone Else's Squad"
    )

    with pytest.raises(PermissionError):
        await booking_service.invite_squad(
            db, game_id=game.id, squad_id=other_squad.id, organiser_id=organiser.id
        )


async def test_marketplace_join_still_works_alongside_invitations(db, setup):
    """A stranger joining from the marketplace shares the same slot pool."""
    game, squad, organiser = setup["game"], setup["squad"], setup["organiser"]

    await booking_service.invite_squad(
        db, game_id=game.id, squad_id=squad.id, organiser_id=organiser.id
    )
    for p in setup["players"][:9]:
        await booking_service.respond_to_invitation(
            db, game_id=game.id, player_id=p.id, attending=True
        )

    booking = await booking_service.create_booking(
        db, game.id, setup["stranger"].id
    )

    assert booking.status == "confirmed"
    await db.refresh(game)
    assert game.current_players == 10
    assert game.status == "full"
