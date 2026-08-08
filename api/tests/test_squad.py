import pytest

from models.user import User
from services.squad import squad_service


@pytest.fixture
async def seed_users(db):
    organiser = User(
        firebase_uid="organiser_uid",
        email="organiser@example.com",
        display_name="Organiser",
        is_organiser=True,
    )
    other_organiser = User(
        firebase_uid="other_organiser_uid",
        email="other@example.com",
        display_name="Other Organiser",
        is_organiser=True,
    )
    registered_player = User(
        firebase_uid="player_uid",
        email="player@example.com",
        display_name="Registered Player",
    )
    db.add_all([organiser, other_organiser, registered_player])
    await db.commit()
    for u in (organiser, other_organiser, registered_player):
        await db.refresh(u)

    return {
        "organiser": organiser,
        "other_organiser": other_organiser,
        "registered_player": registered_player,
    }


@pytest.fixture
async def squad(db, seed_users):
    return await squad_service.create_squad(
        db, organiser_id=seed_users["organiser"].id, name="Tuesday Regulars"
    )


async def test_create_squad(db, seed_users):
    organiser = seed_users["organiser"]

    created = await squad_service.create_squad(
        db, organiser_id=organiser.id, name="Tuesday Regulars"
    )

    assert created.name == "Tuesday Regulars"
    assert created.organiser_id == organiser.id


async def test_add_registered_member_is_active_immediately(db, seed_users, squad):
    organiser = seed_users["organiser"]
    player = seed_users["registered_player"]

    member = await squad_service.add_member(
        db,
        squad_id=squad.id,
        organiser_id=organiser.id,
        display_name="Registered Player",
        email=player.email,
    )

    # Email matches an existing user, so they join the pool straight away.
    assert member.user_id == player.id
    assert member.status == "active"


async def test_add_unregistered_member_creates_pending_invite(db, seed_users, squad):
    organiser = seed_users["organiser"]

    member = await squad_service.add_member(
        db,
        squad_id=squad.id,
        organiser_id=organiser.id,
        display_name="Barry From Work",
        email="barry@example.com",
    )

    assert member.user_id is None
    assert member.status == "invited"
    assert member.display_name == "Barry From Work"
    assert member.invite_email == "barry@example.com"


async def test_invite_email_is_normalised_to_lowercase(db, seed_users, squad):
    organiser = seed_users["organiser"]

    member = await squad_service.add_member(
        db,
        squad_id=squad.id,
        organiser_id=organiser.id,
        display_name="Barry From Work",
        email="Barry@Example.COM",
    )

    assert member.invite_email == "barry@example.com"


async def test_cannot_add_same_user_twice(db, seed_users, squad):
    organiser = seed_users["organiser"]
    player = seed_users["registered_player"]

    await squad_service.add_member(
        db,
        squad_id=squad.id,
        organiser_id=organiser.id,
        display_name="Registered Player",
        email=player.email,
    )

    with pytest.raises(ValueError, match="already in this squad"):
        await squad_service.add_member(
            db,
            squad_id=squad.id,
            organiser_id=organiser.id,
            display_name="Registered Player Again",
            email=player.email,
        )


async def test_cannot_add_same_pending_email_twice(db, seed_users, squad):
    organiser = seed_users["organiser"]

    await squad_service.add_member(
        db,
        squad_id=squad.id,
        organiser_id=organiser.id,
        display_name="Barry",
        email="barry@example.com",
    )

    with pytest.raises(ValueError, match="already in this squad"):
        await squad_service.add_member(
            db,
            squad_id=squad.id,
            organiser_id=organiser.id,
            display_name="Barry Again",
            email="barry@example.com",
        )


async def test_non_organiser_cannot_add_member(db, seed_users, squad):
    intruder = seed_users["other_organiser"]

    with pytest.raises(PermissionError):
        await squad_service.add_member(
            db,
            squad_id=squad.id,
            organiser_id=intruder.id,
            display_name="Sneaky Addition",
            email="sneaky@example.com",
        )


async def test_remove_member(db, seed_users, squad):
    organiser = seed_users["organiser"]

    member = await squad_service.add_member(
        db,
        squad_id=squad.id,
        organiser_id=organiser.id,
        display_name="Barry",
        email="barry@example.com",
    )

    await squad_service.remove_member(
        db, squad_id=squad.id, member_id=member.id, organiser_id=organiser.id
    )

    remaining = await squad_service.list_members(db, squad_id=squad.id)
    assert remaining == []


async def test_non_organiser_cannot_remove_member(db, seed_users, squad):
    organiser = seed_users["organiser"]
    intruder = seed_users["other_organiser"]

    member = await squad_service.add_member(
        db,
        squad_id=squad.id,
        organiser_id=organiser.id,
        display_name="Barry",
        email="barry@example.com",
    )

    with pytest.raises(PermissionError):
        await squad_service.remove_member(
            db, squad_id=squad.id, member_id=member.id, organiser_id=intruder.id
        )


async def test_link_pending_members_on_registration(db, seed_users, squad):
    organiser = seed_users["organiser"]

    member = await squad_service.add_member(
        db,
        squad_id=squad.id,
        organiser_id=organiser.id,
        display_name="Barry From Work",
        email="barry@example.com",
    )
    assert member.user_id is None

    # Barry finally signs up.
    barry = User(
        firebase_uid="barry_uid",
        email="barry@example.com",
        display_name="Barry Murphy",
    )
    db.add(barry)
    await db.commit()
    await db.refresh(barry)

    linked = await squad_service.link_pending_members(db, barry)

    assert linked == 1
    await db.refresh(member)
    assert member.user_id == barry.id
    assert member.status == "active"


async def test_link_pending_members_matches_email_case_insensitively(
    db, seed_users, squad
):
    organiser = seed_users["organiser"]

    member = await squad_service.add_member(
        db,
        squad_id=squad.id,
        organiser_id=organiser.id,
        display_name="Barry From Work",
        email="barry@example.com",
    )

    # Registers with differently-cased email than the invite used.
    barry = User(
        firebase_uid="barry_uid",
        email="BARRY@example.com",
        display_name="Barry Murphy",
    )
    db.add(barry)
    await db.commit()
    await db.refresh(barry)

    linked = await squad_service.link_pending_members(db, barry)

    assert linked == 1
    await db.refresh(member)
    assert member.user_id == barry.id


async def test_link_pending_members_ignores_unrelated_invites(db, seed_users, squad):
    organiser = seed_users["organiser"]

    await squad_service.add_member(
        db,
        squad_id=squad.id,
        organiser_id=organiser.id,
        display_name="Barry From Work",
        email="barry@example.com",
    )

    stranger = User(
        firebase_uid="stranger_uid",
        email="stranger@example.com",
        display_name="Stranger",
    )
    db.add(stranger)
    await db.commit()
    await db.refresh(stranger)

    linked = await squad_service.link_pending_members(db, stranger)

    assert linked == 0


async def test_link_pending_members_handles_user_without_email(db, seed_users, squad):
    organiser = seed_users["organiser"]

    await squad_service.add_member(
        db,
        squad_id=squad.id,
        organiser_id=organiser.id,
        display_name="Barry From Work",
        email="barry@example.com",
    )

    # Phone-auth users have no email address at all.
    phone_user = User(firebase_uid="phone_uid", email=None, display_name="Phone User")
    db.add(phone_user)
    await db.commit()
    await db.refresh(phone_user)

    linked = await squad_service.link_pending_members(db, phone_user)

    assert linked == 0


async def test_list_squads_only_returns_own_squads(db, seed_users, squad):
    organiser = seed_users["organiser"]
    other = seed_users["other_organiser"]

    await squad_service.create_squad(
        db, organiser_id=other.id, name="Someone Else's Squad"
    )

    mine = await squad_service.list_squads(db, organiser_id=organiser.id)

    assert len(mine) == 1
    assert mine[0].id == squad.id
