from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy.future import select

from models.booking import Booking
from models.game import Game
from models.user import User
from models.venue import Venue
from services.series import as_utc, series_service
from services.squad import squad_service

# A fixed Tuesday, so recurrence expectations don't drift with the real clock.
TUESDAY = datetime(2026, 9, 1, 18, 0, tzinfo=timezone.utc)


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
    db.add(venue)
    await db.commit()
    await db.refresh(venue)
    for u in (organiser, stranger, *players):
        await db.refresh(u)

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
        "squad": squad,
    }


async def make_series(db, setup, **overrides):
    kwargs = dict(
        organiser_id=setup["organiser"].id,
        venue_id=setup["venue"].id,
        squad_id=setup["squad"].id,
        title="Tuesday Night 5s",
        starts_at=TUESDAY,
        rrule="FREQ=WEEKLY;BYDAY=TU",
        duration_minutes=60,
        max_players=10,
        skill_level=3,
    )
    kwargs.update(overrides)
    return await series_service.create_series(db, **kwargs)


async def test_create_series(db, setup):
    series = await make_series(db, setup)

    assert series.title == "Tuesday Night 5s"
    assert series.rrule == "FREQ=WEEKLY;BYDAY=TU"
    assert series.is_active is True


async def test_create_series_rejects_invalid_rrule(db, setup):
    with pytest.raises(ValueError, match="recurrence rule"):
        await make_series(db, setup, rrule="NOT-A-RULE")


async def test_materialise_creates_upcoming_instances(db, setup):
    series = await make_series(db, setup)

    # The horizon window is inclusive: [now, now + horizon_days].
    # From the first Tuesday, 15 days covers 3 Tuesdays.
    created = await series_service.materialise_upcoming(
        db, now=TUESDAY, horizon_days=15
    )

    assert len(created) == 3
    assert all(g.series_id == series.id for g in created)
    # SQLite returns naive datetimes where Postgres returns aware ones.
    assert [as_utc(g.starts_at) for g in created] == [
        TUESDAY,
        TUESDAY + timedelta(days=7),
        TUESDAY + timedelta(days=14),
    ]


async def test_materialised_games_copy_series_settings(db, setup):
    await make_series(db, setup, max_players=12, duration_minutes=90, skill_level=4)

    created = await series_service.materialise_upcoming(
        db, now=TUESDAY, horizon_days=7
    )

    game = created[0]
    assert game.max_players == 12
    assert game.duration_minutes == 90
    assert game.skill_level == 4
    assert game.is_recurring is True
    assert game.current_players == 0
    assert game.status == "open"


async def test_materialise_is_idempotent(db, setup):
    await make_series(db, setup)

    first = await series_service.materialise_upcoming(
        db, now=TUESDAY, horizon_days=15
    )
    second = await series_service.materialise_upcoming(
        db, now=TUESDAY, horizon_days=15
    )

    assert len(first) == 3
    assert second == []  # nothing new to create

    result = await db.execute(select(Game))
    assert len(list(result.scalars().all())) == 3


async def test_materialise_extends_horizon_without_duplicating(db, setup):
    await make_series(db, setup)

    await series_service.materialise_upcoming(db, now=TUESDAY, horizon_days=3)
    later = await series_service.materialise_upcoming(
        db, now=TUESDAY, horizon_days=15
    )

    # Only the two newly-in-range Tuesdays are added.
    assert len(later) == 2


async def test_materialise_auto_invites_the_squad(db, setup):
    """This is the 'notify them for each instance' requirement."""
    await make_series(db, setup)

    created = await series_service.materialise_upcoming(
        db, now=TUESDAY, horizon_days=7
    )
    game = created[0]

    result = await db.execute(select(Booking).where(Booking.game_id == game.id))
    bookings = list(result.scalars().all())

    assert len(bookings) == 3
    assert {b.status for b in bookings} == {"invited"}


async def test_invitations_do_not_fill_the_materialised_game(db, setup):
    await make_series(db, setup)

    created = await series_service.materialise_upcoming(
        db, now=TUESDAY, horizon_days=7
    )

    await db.refresh(created[0])
    assert created[0].current_players == 0
    assert created[0].status == "open"


async def test_series_without_squad_creates_games_but_no_invites(db, setup):
    await make_series(db, setup, squad_id=None)

    # A 3-day window from the first Tuesday covers exactly one occurrence.
    created = await series_service.materialise_upcoming(
        db, now=TUESDAY, horizon_days=3
    )

    assert len(created) == 1
    result = await db.execute(
        select(Booking).where(Booking.game_id == created[0].id)
    )
    assert list(result.scalars().all()) == []


async def test_inactive_series_is_not_materialised(db, setup):
    series = await make_series(db, setup)
    await series_service.set_active(
        db, series_id=series.id, organiser_id=setup["organiser"].id, is_active=False
    )

    created = await series_service.materialise_upcoming(
        db, now=TUESDAY, horizon_days=15
    )

    assert created == []


async def test_materialise_skips_occurrences_already_in_the_past(db, setup):
    await make_series(db, setup)

    # Two weeks after the first occurrence, only future Tuesdays should appear.
    now = TUESDAY + timedelta(days=14, hours=1)
    created = await series_service.materialise_upcoming(db, now=now, horizon_days=7)

    assert len(created) == 1
    assert as_utc(created[0].starts_at) == TUESDAY + timedelta(days=21)


async def test_non_organiser_cannot_deactivate_series(db, setup):
    series = await make_series(db, setup)

    with pytest.raises(PermissionError):
        await series_service.set_active(
            db,
            series_id=series.id,
            organiser_id=setup["stranger"].id,
            is_active=False,
        )


async def test_list_series_scoped_to_organiser(db, setup):
    series = await make_series(db, setup)

    mine = await series_service.list_series(db, organiser_id=setup["organiser"].id)
    theirs = await series_service.list_series(db, organiser_id=setup["stranger"].id)

    assert [s.id for s in mine] == [series.id]
    assert theirs == []


async def test_daily_rrule_expands_correctly(db, setup):
    await make_series(db, setup, rrule="FREQ=DAILY")

    created = await series_service.materialise_upcoming(
        db, now=TUESDAY, horizon_days=3
    )

    assert [as_utc(g.starts_at) for g in created] == [
        TUESDAY,
        TUESDAY + timedelta(days=1),
        TUESDAY + timedelta(days=2),
        TUESDAY + timedelta(days=3),
    ]


async def test_rrule_with_count_stops_generating(db, setup):
    await make_series(db, setup, rrule="FREQ=WEEKLY;BYDAY=TU;COUNT=2")

    created = await series_service.materialise_upcoming(
        db, now=TUESDAY, horizon_days=60
    )

    assert len(created) == 2
