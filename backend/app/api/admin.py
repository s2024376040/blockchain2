from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.api.dependencies import require_admin
from app.database.session import get_db
from app.models import AuditEvent, Block, Transaction, User
from app.services.ledger import load_chain

router = APIRouter(prefix="/admin", tags=["admin"])


@router.get("/dashboard")
def dashboard(db: Session = Depends(get_db), _: User = Depends(require_admin)) -> dict[str, object]:
    chain = load_chain(db)
    return {
        "registered_users": db.scalar(select(func.count()).select_from(User)) or 0,
        "transactions": db.scalar(select(func.count()).select_from(Transaction)) or 0,
        "btc_traded": str(db.scalar(select(func.coalesce(func.sum(Transaction.btc_quantity), 0))) or 0),
        "blocks": db.scalar(select(func.count()).select_from(Block)) or 0,
        "valid_blocks": sum(
            chain.verify_block(block) and chain.verify_block_link(index)
            for index, block in enumerate(chain.blocks)
        ),
        "audit_events": db.scalar(select(func.count()).select_from(AuditEvent)) or 0,
        "invalid_verification_attempts": db.scalar(
            select(func.count()).select_from(AuditEvent).where(
                AuditEvent.action == "INVALID_VERIFICATION_ATTEMPT"
            )
        )
        or 0,
    }


@router.get("/users")
def users(db: Session = Depends(get_db), _: User = Depends(require_admin)) -> list[dict[str, str]]:
    records = db.scalars(select(User).order_by(User.created_at.desc())).all()
    return [{"id": user.id, "email": user.email, "role": user.role} for user in records]


@router.get("/transactions")
def transactions(
    db: Session = Depends(get_db), _: User = Depends(require_admin)
) -> list[dict[str, object]]:
    records = db.scalars(select(Transaction).order_by(Transaction.timestamp.desc()).limit(500)).all()
    return [
        {
            "id": record.id,
            "user_id": record.user_id,
            "transaction_type": record.transaction_type,
            "btc_quantity": str(record.btc_quantity),
            "price_usd": str(record.price_usd),
            "total_usd": str(record.total_usd),
            "timestamp": record.timestamp.isoformat(),
            "transaction_hash": record.transaction_hash,
            "block_index": record.block_index,
        }
        for record in records
    ]
