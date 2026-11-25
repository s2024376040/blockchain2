from datetime import datetime, timezone
from decimal import Decimal

from sqlalchemy import DateTime, ForeignKey, Integer, Numeric, String, Text, event
from sqlalchemy.orm import Mapped, mapped_column

from app.database.session import Base


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    email: Mapped[str] = mapped_column(String(320), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    role: Mapped[str] = mapped_column(String(16), default="user")
    usd_balance: Mapped[Decimal] = mapped_column(Numeric(20, 2), default=Decimal("100000.00"))
    btc_balance: Mapped[Decimal] = mapped_column(Numeric(20, 8), default=Decimal("0"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)


class Transaction(Base):
    __tablename__ = "transactions"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    transaction_type: Mapped[str] = mapped_column(String(8))
    btc_quantity: Mapped[Decimal] = mapped_column(Numeric(20, 8))
    price_usd: Mapped[Decimal] = mapped_column(Numeric(20, 2))
    total_usd: Mapped[Decimal] = mapped_column(Numeric(20, 2))
    timestamp: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    transaction_hash: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    block_index: Mapped[int] = mapped_column(Integer)
    payload_json: Mapped[str] = mapped_column(Text)


class Block(Base):
    __tablename__ = "blocks"

    index: Mapped[int] = mapped_column(Integer, primary_key=True)
    timestamp: Mapped[str] = mapped_column(String(40))
    previous_hash: Mapped[str] = mapped_column(String(64))
    merkle_root: Mapped[str] = mapped_column(String(64))
    block_hash: Mapped[str] = mapped_column(String(64), unique=True)
    transactions_json: Mapped[str] = mapped_column(Text)
    transaction_hashes_json: Mapped[str] = mapped_column(Text)


class AuditEvent(Base):
    __tablename__ = "audit_events"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    actor_user_id: Mapped[str | None] = mapped_column(String(36), index=True)
    action: Mapped[str] = mapped_column(String(80))
    details_json: Mapped[str] = mapped_column(Text)
    timestamp: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)


def _reject_committed_block_change(mapper, connection, target) -> None:
    raise RuntimeError("Committed blocks are append-only and cannot be changed or deleted.")


event.listen(Block, "before_update", _reject_committed_block_change)
event.listen(Block, "before_delete", _reject_committed_block_change)
event.listen(Transaction, "before_update", _reject_committed_block_change)
event.listen(Transaction, "before_delete", _reject_committed_block_change)
event.listen(AuditEvent, "before_update", _reject_committed_block_change)
event.listen(AuditEvent, "before_delete", _reject_committed_block_change)
