from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.dependencies import get_current_user
from app.database.session import get_db
from app.models import AuditEvent, Transaction, User
from app.schemas.api import AuditResponse, TransactionResponse

router = APIRouter(prefix="/audit", tags=["audit"])


@router.get("/history", response_model=list[AuditResponse])
def audit_history(
    start: datetime | None = None,
    end: datetime | None = None,
    transaction_id: str | None = None,
    user_id: str | None = None,
    status: str | None = Query(default=None, pattern="^(valid|invalid)$"),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> list[AuditEvent]:
    query = select(AuditEvent).order_by(AuditEvent.timestamp.desc()).limit(200)
    if user.role != "admin":
        query = query.where(AuditEvent.actor_user_id == user.id)
    elif user_id:
        query = query.where(AuditEvent.actor_user_id == user_id)
    if start:
        query = query.where(AuditEvent.timestamp >= start)
    if end:
        query = query.where(AuditEvent.timestamp <= end)
    if transaction_id:
        query = query.where(AuditEvent.details_json.contains(transaction_id))
    if status == "valid":
        query = query.where(AuditEvent.action == "TRANSACTION_VERIFICATION")
    elif status == "invalid":
        query = query.where(AuditEvent.action == "INVALID_VERIFICATION_ATTEMPT")
    return db.scalars(query).all()


@router.get("/transactions/{transaction_id}", response_model=TransactionResponse)
def audit_transaction(
    transaction_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> Transaction:
    transaction = db.get(Transaction, transaction_id)
    if transaction is None or (user.role != "admin" and transaction.user_id != user.id):
        raise HTTPException(status_code=404, detail="Transaction not found.")
    return transaction
