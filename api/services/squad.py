import logging
import uuid

from sqlalchemy import delete, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from config import get_settings
from models.squad import Squad, SquadMember
from models.user import User
from services.email import email_service
from services.i18n import t

logger = logging.getLogger(__name__)


class SquadService:
    """Manages an organiser's pool of regular players.

    A squad may be larger than any single game's capacity — every member is
    invited to each match and slots go first-come-first-served.
    """

    async def create_squad(
        self, db: AsyncSession, organiser_id: uuid.UUID, name: str
    ) -> Squad:
        squad = Squad(organiser_id=organiser_id, name=name)
        db.add(squad)
        await db.commit()
        await db.refresh(squad)
        return squad

    async def get_squad(
        self, db: AsyncSession, squad_id: uuid.UUID
    ) -> Squad | None:
        result = await db.execute(select(Squad).where(Squad.id == squad_id))
        return result.scalar_one_or_none()

    async def list_squads(
        self, db: AsyncSession, organiser_id: uuid.UUID
    ) -> list[Squad]:
        result = await db.execute(
            select(Squad)
            .where(Squad.organiser_id == organiser_id)
            .order_by(Squad.created_at.asc())
        )
        return list(result.scalars().all())

    async def member_counts(
        self, db: AsyncSession, squad_ids: list[uuid.UUID]
    ) -> dict[uuid.UUID, tuple[int, int]]:
        """Active and pending member counts per squad, in one query.

        Returns {squad_id: (active, pending)}. Squads with no members are
        absent, so callers should default to (0, 0).
        """
        if not squad_ids:
            return {}

        result = await db.execute(
            select(
                SquadMember.squad_id,
                func.count().filter(SquadMember.user_id.is_not(None)),
                func.count().filter(SquadMember.user_id.is_(None)),
            )
            .where(SquadMember.squad_id.in_(squad_ids))
            .group_by(SquadMember.squad_id)
        )
        return {row[0]: (row[1], row[2]) for row in result.all()}

    async def list_members(
        self, db: AsyncSession, squad_id: uuid.UUID
    ) -> list[SquadMember]:
        result = await db.execute(
            select(SquadMember)
            .where(SquadMember.squad_id == squad_id)
            .order_by(SquadMember.created_at.asc())
        )
        return list(result.scalars().all())

    async def _owned_squad(
        self, db: AsyncSession, squad_id: uuid.UUID, organiser_id: uuid.UUID
    ) -> Squad:
        squad = await self.get_squad(db, squad_id)
        if squad is None:
            raise ValueError("Squad not found.")
        if squad.organiser_id != organiser_id:
            raise PermissionError("Only the squad organiser can modify it.")
        return squad

    async def rename_squad(
        self,
        db: AsyncSession,
        squad_id: uuid.UUID,
        organiser_id: uuid.UUID,
        name: str,
    ) -> Squad:
        squad = await self._owned_squad(db, squad_id, organiser_id)
        squad.name = name
        await db.commit()
        await db.refresh(squad)
        return squad

    async def delete_squad(
        self, db: AsyncSession, squad_id: uuid.UUID, organiser_id: uuid.UUID
    ) -> None:
        await self._owned_squad(db, squad_id, organiser_id)
        # Memberships reference the squad, so they go first.
        await db.execute(delete(SquadMember).where(SquadMember.squad_id == squad_id))
        await db.execute(delete(Squad).where(Squad.id == squad_id))
        await db.commit()

    async def add_member(
        self,
        db: AsyncSession,
        squad_id: uuid.UUID,
        organiser_id: uuid.UUID,
        display_name: str,
        email: str | None = None,
        phone: str | None = None,
    ) -> SquadMember:
        squad = await self._owned_squad(db, squad_id, organiser_id)

        normalised_email = email.strip().lower() if email else None

        # If the email belongs to an existing account, link immediately so the
        # member is playable straight away rather than sitting in `invited`.
        existing_user: User | None = None
        if normalised_email:
            user_result = await db.execute(
                select(User).where(func.lower(User.email) == normalised_email)
            )
            existing_user = user_result.scalar_one_or_none()

        await self._reject_duplicate(db, squad_id, existing_user, normalised_email)

        member = SquadMember(
            squad_id=squad_id,
            user_id=existing_user.id if existing_user else None,
            display_name=display_name,
            invite_email=normalised_email,
            invite_phone=phone,
            status="active" if existing_user else "invited",
        )
        db.add(member)
        await db.commit()
        await db.refresh(member)

        if member.status == "invited" and normalised_email:
            await self._send_invite_email(db, squad, member)

        return member

    async def _reject_duplicate(
        self,
        db: AsyncSession,
        squad_id: uuid.UUID,
        existing_user: User | None,
        normalised_email: str | None,
    ) -> None:
        """Guard both ways someone can already be in a squad.

        The unique constraints cover this at the database level, but catching it
        here gives a usable error instead of an IntegrityError.
        """
        if existing_user is not None:
            dupe = await db.execute(
                select(SquadMember).where(
                    SquadMember.squad_id == squad_id,
                    SquadMember.user_id == existing_user.id,
                )
            )
            if dupe.scalar_one_or_none() is not None:
                raise ValueError("That player is already in this squad.")

        if normalised_email:
            dupe = await db.execute(
                select(SquadMember).where(
                    SquadMember.squad_id == squad_id,
                    SquadMember.invite_email == normalised_email,
                )
            )
            if dupe.scalar_one_or_none() is not None:
                raise ValueError("That email is already in this squad.")

    async def _send_invite_email(
        self, db: AsyncSession, squad: Squad, member: SquadMember
    ) -> None:
        """Invite someone who has no account yet.

        Unregistered invitees have no stored locale, so the organiser's is the
        best available proxy — a Dublin organiser inviting mates almost
        certainly wants the same language they use themselves.
        """
        organiser_result = await db.execute(
            select(User).where(User.id == squad.organiser_id)
        )
        organiser = organiser_result.scalar_one_or_none()
        organiser_name = (organiser.display_name if organiser else None) or "An organiser"
        locale = organiser.locale if organiser else None

        try:
            await email_service.send(
                to=member.invite_email,
                subject=t(
                    "squad_invite.subject",
                    locale,
                    organiser_name=organiser_name,
                ),
                html=t(
                    "squad_invite.body_html",
                    locale,
                    member_name=member.display_name,
                    organiser_name=organiser_name,
                    squad_name=squad.name,
                    join_url=get_settings().app_base_url,
                ),
            )
        except Exception as e:
            # A failed invite email must not undo a successful squad addition —
            # the organiser can always resend.
            logger.error("Failed to send squad invite to %s: %s", member.invite_email, e)

    async def remove_member(
        self,
        db: AsyncSession,
        squad_id: uuid.UUID,
        member_id: uuid.UUID,
        organiser_id: uuid.UUID,
    ) -> None:
        await self._owned_squad(db, squad_id, organiser_id)

        result = await db.execute(
            select(SquadMember).where(
                SquadMember.id == member_id,
                SquadMember.squad_id == squad_id,
            )
        )
        member = result.scalar_one_or_none()
        if member is None:
            raise ValueError("Squad member not found.")

        await db.execute(delete(SquadMember).where(SquadMember.id == member_id))
        await db.commit()

    async def link_pending_members(self, db: AsyncSession, user: User) -> int:
        """Attach a freshly-registered user to any invites awaiting them.

        Called on registration. Matches on email because that is the only
        handle an organiser had when inviting someone with no account.
        Returns the number of memberships linked.
        """
        if not user.email:
            return 0

        normalised_email = user.email.strip().lower()

        result = await db.execute(
            select(SquadMember).where(
                SquadMember.invite_email == normalised_email,
                SquadMember.user_id.is_(None),
            )
        )
        pending = list(result.scalars().all())
        if not pending:
            return 0

        # Skip any squad where this user somehow already has a membership row,
        # which would violate the (squad_id, user_id) unique constraint.
        already_in = await db.execute(
            select(SquadMember.squad_id).where(SquadMember.user_id == user.id)
        )
        occupied = set(already_in.scalars().all())

        linked = 0
        for member in pending:
            if member.squad_id in occupied:
                continue
            member.user_id = user.id
            member.status = "active"
            linked += 1

        await db.commit()
        return linked


squad_service = SquadService()
