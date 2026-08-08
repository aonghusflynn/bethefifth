import pytest

from models.user import User

ORGANISER_AUTH = {"Authorization": "Bearer mock-token-organiser_uid"}
INTRUDER_AUTH = {"Authorization": "Bearer mock-token-intruder_uid"}


@pytest.fixture
async def users(db):
    organiser = User(
        firebase_uid="organiser_uid",
        email="organiser@example.com",
        display_name="Organiser",
        is_organiser=True,
    )
    intruder = User(
        firebase_uid="intruder_uid",
        email="intruder@example.com",
        display_name="Intruder",
    )
    db.add_all([organiser, intruder])
    await db.commit()
    await db.refresh(organiser)
    await db.refresh(intruder)
    return {"organiser": organiser, "intruder": intruder}


@pytest.fixture
async def squad_id(client, users):
    response = await client.post(
        "/api/v1/squads", json={"name": "Tuesday Regulars"}, headers=ORGANISER_AUTH
    )
    assert response.status_code == 201
    return response.json()["id"]


async def test_create_squad(client, users):
    response = await client.post(
        "/api/v1/squads", json={"name": "Tuesday Regulars"}, headers=ORGANISER_AUTH
    )

    assert response.status_code == 201
    body = response.json()
    assert body["name"] == "Tuesday Regulars"
    assert body["organiser_id"] == str(users["organiser"].id)


async def test_create_squad_requires_auth(client, users):
    response = await client.post("/api/v1/squads", json={"name": "No Auth"})
    assert response.status_code in (401, 403)


async def test_create_squad_rejects_empty_name(client, users):
    response = await client.post(
        "/api/v1/squads", json={"name": ""}, headers=ORGANISER_AUTH
    )
    assert response.status_code == 422


async def test_list_squads_scoped_to_organiser(client, users, squad_id):
    mine = await client.get("/api/v1/squads", headers=ORGANISER_AUTH)
    assert mine.status_code == 200
    assert [s["id"] for s in mine.json()] == [squad_id]

    theirs = await client.get("/api/v1/squads", headers=INTRUDER_AUTH)
    assert theirs.status_code == 200
    assert theirs.json() == []


async def test_add_member_with_unknown_email_is_invited(client, users, squad_id):
    response = await client.post(
        f"/api/v1/squads/{squad_id}/members",
        json={"display_name": "Barry From Work", "email": "barry@example.com"},
        headers=ORGANISER_AUTH,
    )

    assert response.status_code == 201
    body = response.json()
    assert body["status"] == "invited"
    assert body["user_id"] is None
    assert body["invite_email"] == "barry@example.com"


async def test_add_member_with_known_email_is_active(client, users, squad_id):
    response = await client.post(
        f"/api/v1/squads/{squad_id}/members",
        json={"display_name": "Intruder", "email": "intruder@example.com"},
        headers=ORGANISER_AUTH,
    )

    assert response.status_code == 201
    body = response.json()
    assert body["status"] == "active"
    assert body["user_id"] == str(users["intruder"].id)


async def test_add_member_rejects_malformed_email(client, users, squad_id):
    response = await client.post(
        f"/api/v1/squads/{squad_id}/members",
        json={"display_name": "Typo", "email": "not-an-email"},
        headers=ORGANISER_AUTH,
    )
    assert response.status_code == 422


async def test_add_duplicate_member_returns_400(client, users, squad_id):
    payload = {"display_name": "Barry", "email": "barry@example.com"}
    first = await client.post(
        f"/api/v1/squads/{squad_id}/members", json=payload, headers=ORGANISER_AUTH
    )
    assert first.status_code == 201

    second = await client.post(
        f"/api/v1/squads/{squad_id}/members", json=payload, headers=ORGANISER_AUTH
    )
    assert second.status_code == 400


async def test_non_organiser_cannot_add_member(client, users, squad_id):
    response = await client.post(
        f"/api/v1/squads/{squad_id}/members",
        json={"display_name": "Sneaky", "email": "sneaky@example.com"},
        headers=INTRUDER_AUTH,
    )
    assert response.status_code == 403


async def test_non_organiser_cannot_view_squad(client, users, squad_id):
    response = await client.get(f"/api/v1/squads/{squad_id}", headers=INTRUDER_AUTH)
    assert response.status_code == 403


async def test_get_squad_includes_members(client, users, squad_id):
    await client.post(
        f"/api/v1/squads/{squad_id}/members",
        json={"display_name": "Barry", "email": "barry@example.com"},
        headers=ORGANISER_AUTH,
    )

    response = await client.get(f"/api/v1/squads/{squad_id}", headers=ORGANISER_AUTH)

    assert response.status_code == 200
    body = response.json()
    assert body["name"] == "Tuesday Regulars"
    assert len(body["members"]) == 1
    assert body["members"][0]["display_name"] == "Barry"


async def test_remove_member(client, users, squad_id):
    created = await client.post(
        f"/api/v1/squads/{squad_id}/members",
        json={"display_name": "Barry", "email": "barry@example.com"},
        headers=ORGANISER_AUTH,
    )
    member_id = created.json()["id"]

    deleted = await client.delete(
        f"/api/v1/squads/{squad_id}/members/{member_id}", headers=ORGANISER_AUTH
    )
    assert deleted.status_code == 204

    squad = await client.get(f"/api/v1/squads/{squad_id}", headers=ORGANISER_AUTH)
    assert squad.json()["members"] == []


async def test_rename_squad(client, users, squad_id):
    response = await client.patch(
        f"/api/v1/squads/{squad_id}",
        json={"name": "Thursday Regulars"},
        headers=ORGANISER_AUTH,
    )
    assert response.status_code == 200
    assert response.json()["name"] == "Thursday Regulars"


async def test_delete_squad_removes_members_too(client, users, squad_id):
    await client.post(
        f"/api/v1/squads/{squad_id}/members",
        json={"display_name": "Barry", "email": "barry@example.com"},
        headers=ORGANISER_AUTH,
    )

    deleted = await client.delete(f"/api/v1/squads/{squad_id}", headers=ORGANISER_AUTH)
    assert deleted.status_code == 204

    gone = await client.get(f"/api/v1/squads/{squad_id}", headers=ORGANISER_AUTH)
    assert gone.status_code == 404


async def test_registration_links_pending_squad_invite(client, users, squad_id):
    """The full handshake: invite by email, then that person signs up."""
    invited = await client.post(
        f"/api/v1/squads/{squad_id}/members",
        json={"display_name": "Barry From Work", "email": "barry@example.com"},
        headers=ORGANISER_AUTH,
    )
    assert invited.json()["status"] == "invited"

    # Barry registers. The mock token derives the email barry@example.com,
    # matching the pending invite.
    registered = await client.post(
        "/api/v1/auth/register",
        json={},
        headers={"Authorization": "Bearer mock-token-barry"},
    )
    assert registered.status_code == 201

    squad = await client.get(f"/api/v1/squads/{squad_id}", headers=ORGANISER_AUTH)
    member = squad.json()["members"][0]
    assert member["status"] == "active"
    assert member["user_id"] == registered.json()["id"]
