import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Index, String, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column

from database import Base


class Squad(Base):
    """A persistent pool of players an organiser draws on for their games.

    A squad is deliberately allowed to be larger than a game's `max_players`:
    every member is invited to each match and slots are filled
    first-come-first-served by whoever accepts.
    """

    __tablename__ = "squads"

    id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    organiser_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("users.id"), nullable=False
    )
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    __table_args__ = (Index("ix_squads_organiser_id", "organiser_id"),)


class SquadMember(Base):
    """One player's membership of a squad.

    `user_id` is nullable on purpose: an organiser can add a friend who has no
    BeTheFifth account yet. Those rows sit in `invited` status carrying only a
    display name and an email, and are linked to a real user by
    `SquadService.link_pending_members` when that person registers.
    """

    __tablename__ = "squad_members"

    id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    squad_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("squads.id"), nullable=False
    )
    user_id: Mapped[uuid.UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("users.id"), nullable=True
    )
    display_name: Mapped[str] = mapped_column(String(100), nullable=False)
    invite_email: Mapped[str | None] = mapped_column(String(255), nullable=True)
    invite_phone: Mapped[str | None] = mapped_column(String(20), nullable=True)
    status: Mapped[str] = mapped_column(
        String(20), default="invited", nullable=False
    )  # invited (awaiting sign-up), active (linked to a real user)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    __table_args__ = (
        # NULLs compare as distinct, so these only constrain rows that actually
        # carry a user_id / invite_email — multiple pending invites coexist fine.
        UniqueConstraint("squad_id", "user_id", name="uq_squad_member_user"),
        UniqueConstraint("squad_id", "invite_email", name="uq_squad_member_email"),
        Index("ix_squad_members_squad_id", "squad_id"),
        Index("ix_squad_members_user_id", "user_id"),
        Index("ix_squad_members_invite_email", "invite_email"),
    )
