from datetime import datetime, timedelta, timezone

import pytest

from models.game import Game
from models.user import User
from models.venue import Venue
from services.booking import booking_service
from services.marketplace import marketplace_service
from services.series import series_service
from services.squad import squad_service

NOW = datetime(2026, 9, 1, 12, 0, tzinfo=timezone.utc)


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
        name="Irishtown", address="Dublin 4", city="Dublin", lat=53.34, lng=-6.22
    )
    other_venue = Venue(
        name="Herbert Park", address="Dublin 4", city="Dublin", lat=53.32, lng=-6.23
    )
    db.add_all([venue, other_venue])
    await db.commit()
    for obj in (organiser, stranger, venue, other_venue, *players):
        await db.refresh(obj)

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

    return {
        "organiser": organiser,
        "stranger": stranger,
        "players": players,
        "venue": venue,
        "other_venue": other_venue,
        "squad": squad,
    }


async def make_game(db, setup, starts_in, visibility="squad_only", **overrides):
    kwargs = dict(
        organiser_id=setup["organiser"].id,
        venue_id=setup["venue"].id,
        title="Tuesday Night 5s",
        starts_at=NOW + starts_in,
        duration_minutes=60,
        max_players=10,
        current_players=0,
        skill_level=3,
        status="open",
        visibility=visibility,
    )
    kwargs.update(overrides)
    game = Game(**kwargs)
    db.add(game)
    await db.commit()
    await db.refresh(game)
    return game


# --- automatic opening -------------------------------------------------------


async def test_short_game_auto_opens_inside_the_window(db, setup):
    game = await make_game(db, setup, starts_in=timedelta(minutes=90))

    opened = await marketplace_service.auto_open_due(db, now=NOW)

    assert [g.id for g in opened] == [game.id]
    await db.refresh(game)
    assert game.visibility == "public"
    assert game.marketplace_opened_at is not None


async def test_game_outside_the_window_is_left_alone(db, setup):
    game = await make_game(db, setup, starts_in=timedelta(hours=5))

    opened = await marketplace_service.auto_open_due(db, now=NOW)

    assert opened == []
    await db.refresh(game)
    assert game.visibility == "squad_only"


async def test_full_game_does_not_open(db, setup):
    game = await make_game(
        db, setup, starts_in=timedelta(minutes=90), current_players=10, status="full"
    )

    opened = await marketplace_service.auto_open_due(db, now=NOW)

    assert opened == []
    await db.refresh(game)
    assert game.visibility == "squad_only"


async def test_cancelled_game_does_not_open(db, setup):
    await make_game(db, setup, starts_in=timedelta(minutes=90), status="cancelled")

    opened = await marketplace_service.auto_open_due(db, now=NOW)

    assert opened == []


async def test_game_already_in_the_past_does_not_open(db, setup):
    await make_game(db, setup, starts_in=timedelta(minutes=-30))

    opened = await marketplace_service.auto_open_due(db, now=NOW)

    assert opened == []


async def test_auto_open_is_idempotent(db, setup):
    await make_game(db, setup, starts_in=timedelta(minutes=90))

    first = await marketplace_service.auto_open_due(db, now=NOW)
    second = await marketplace_service.auto_open_due(db, now=NOW)

    assert len(first) == 1
    assert second == []


# --- manual opening and closing ---------------------------------------------


async def test_organiser_can_open_early(db, setup):
    game = await make_game(db, setup, starts_in=timedelta(days=3))

    opened = await marketplace_service.open_manually(
        db, game_id=game.id, organiser_id=setup["organiser"].id, now=NOW
    )

    assert opened.visibility == "public"
    assert opened.marketplace_opened_at is not None


async def test_non_organiser_cannot_open(db, setup):
    game = await make_game(db, setup, starts_in=timedelta(days=3))

    with pytest.raises(PermissionError):
        await marketplace_service.open_manually(
            db, game_id=game.id, organiser_id=setup["stranger"].id, now=NOW
        )


async def test_organiser_can_close_again_before_anyone_joins(db, setup):
    game = await make_game(db, setup, starts_in=timedelta(days=3))
    await marketplace_service.open_manually(
        db, game_id=game.id, organiser_id=setup["organiser"].id, now=NOW
    )

    closed = await marketplace_service.close_manually(
        db, game_id=game.id, organiser_id=setup["organiser"].id
    )

    assert closed.visibility == "squad_only"
    assert closed.marketplace_opened_at is None


async def test_closing_is_blocked_once_an_outsider_has_joined(db, setup):
    """Pulling the game back would strand someone who already committed."""
    series = await series_service.create_series(
        db,
        organiser_id=setup["organiser"].id,
        venue_id=setup["venue"].id,
        squad_id=setup["squad"].id,
        title="Tuesday Night 5s",
        starts_at=NOW + timedelta(days=3),
        rrule="FREQ=WEEKLY",
    )
    game = await make_game(
        db, setup, starts_in=timedelta(days=3), series_id=series.id
    )
    await marketplace_service.open_manually(
        db, game_id=game.id, organiser_id=setup["organiser"].id, now=NOW
    )
    await booking_service.create_booking(db, game.id, setup["stranger"].id)

    with pytest.raises(ValueError, match="already joined"):
        await marketplace_service.close_manually(
            db, game_id=game.id, organiser_id=setup["organiser"].id
        )


async def test_closing_allowed_when_only_squad_members_joined(db, setup):
    series = await series_service.create_series(
        db,
        organiser_id=setup["organiser"].id,
        venue_id=setup["venue"].id,
        squad_id=setup["squad"].id,
        title="Tuesday Night 5s",
        starts_at=NOW + timedelta(days=3),
        rrule="FREQ=WEEKLY",
    )
    game = await make_game(
        db, setup, starts_in=timedelta(days=3), series_id=series.id
    )
    await marketplace_service.open_manually(
        db, game_id=game.id, organiser_id=setup["organiser"].id, now=NOW
    )
    await booking_service.create_booking(db, game.id, setup["players"][0].id)

    closed = await marketplace_service.close_manually(
        db, game_id=game.id, organiser_id=setup["organiser"].id
    )

    assert closed.visibility == "squad_only"


# --- the "still short" push --------------------------------------------------


async def test_push_fires_inside_the_notify_window(db, setup):
    game = await make_game(
        db, setup, starts_in=timedelta(minutes=45), visibility="public"
    )

    notified = await marketplace_service.notify_due(db, now=NOW)

    assert [g.id for g in notified] == [game.id]
    await db.refresh(game)
    assert game.marketplace_notified_at is not None


async def test_push_does_not_fire_before_the_notify_window(db, setup):
    """Opened at T-2h, but the blast waits until T-1h."""
    await make_game(db, setup, starts_in=timedelta(minutes=100), visibility="public")

    notified = await marketplace_service.notify_due(db, now=NOW)

    assert notified == []


async def test_push_skipped_if_the_game_filled_in_the_meantime(db, setup):
    await make_game(
        db,
        setup,
        starts_in=timedelta(minutes=45),
        visibility="public",
        current_players=10,
        status="full",
    )

    notified = await marketplace_service.notify_due(db, now=NOW)

    assert notified == []


async def test_squad_only_game_is_never_pushed(db, setup):
    await make_game(db, setup, starts_in=timedelta(minutes=45))

    notified = await marketplace_service.notify_due(db, now=NOW)

    assert notified == []


async def test_push_fires_only_once(db, setup):
    await make_game(
        db, setup, starts_in=timedelta(minutes=45), visibility="public"
    )

    first = await marketplace_service.notify_due(db, now=NOW)
    second = await marketplace_service.notify_due(db, now=NOW)

    assert len(first) == 1
    assert second == []


async def test_push_targets_players_with_history_at_that_venue(db, setup):
    """Venue history is the closest thing to a locality signal we have."""
    past_game = await make_game(
        db, setup, starts_in=timedelta(days=-30), visibility="public"
    )
    await booking_service.create_booking(db, past_game.id, setup["stranger"].id)

    game = await make_game(
        db, setup, starts_in=timedelta(minutes=45), visibility="public"
    )

    recipients = await marketplace_service.find_recipients(db, game)

    assert [u.id for u in recipients] == [setup["stranger"].id]


async def test_push_excludes_players_already_on_the_game(db, setup):
    past_game = await make_game(
        db, setup, starts_in=timedelta(days=-30), visibility="public"
    )
    await booking_service.create_booking(db, past_game.id, setup["stranger"].id)

    game = await make_game(
        db, setup, starts_in=timedelta(minutes=45), visibility="public"
    )
    await booking_service.create_booking(db, game.id, setup["stranger"].id)

    recipients = await marketplace_service.find_recipients(db, game)

    assert recipients == []


async def test_push_ignores_history_at_a_different_venue(db, setup):
    past_game = await make_game(
        db,
        setup,
        starts_in=timedelta(days=-30),
        visibility="public",
        venue_id=setup["other_venue"].id,
    )
    await booking_service.create_booking(db, past_game.id, setup["stranger"].id)

    game = await make_game(
        db, setup, starts_in=timedelta(minutes=45), visibility="public"
    )

    recipients = await marketplace_service.find_recipients(db, game)

    assert recipients == []
