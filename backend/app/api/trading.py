import uuid
from datetime import datetime, timezone
from decimal import Decimal, ROUND_HALF_UP

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Request
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.dependencies import get_current_user
from app.blockchain.engine import canonical_json, hash_transaction
from app.core.config import settings
from app.database.session import get_db
from app.models import Block, Transaction, User
from app.schemas.api import TradeRequest, TransactionResponse
from app.services.audit import record_audit
from app.services.ledger import load_chain, persist_block, public_block

router = APIRouter(prefix="/trading", tags=["trading"])
CENT = Decimal("0.01")


def _trade(
    request: Request,
    background_tasks: BackgroundTasks,
    db: Session,
    user_id: str,
    quantity: Decimal,
    action: str,
) -> Transaction:
    quantity = quantity.quantize(Decimal("0.00000001"), rounding=ROUND_HALF_UP)
    price = Decimal(str(settings.demo_btc_price)).quantize(CENT, rounding=ROUND_HALF_UP)
    total = (quantity * price).quantize(CENT, rounding=ROUND_HALF_UP)
    if total <= 0:
        raise HTTPException(status_code=400, detail="Trade value must be at least one cent.")
    transaction_id = str(uuid.uuid4())
    timestamp = datetime.now(timezone.utc)

    try:
        user = db.scalar(select(User).where(User.id == user_id).with_for_update())
        if user is None:
            raise HTTPException(status_code=404, detail="User account no longer exists.")
        db.scalar(select(Block).order_by(Block.index.desc()).limit(1).with_for_update())
        if action == "BUY":
            if Decimal(user.usd_balance) < total:
                raise HTTPException(status_code=400, detail="Insufficient virtual USD balance.")
            user.usd_balance = Decimal(user.usd_balance) - total
            user.btc_balance = Decimal(user.btc_balance) + quantity
        else:
            if Decimal(user.btc_balance) < quantity:
                raise HTTPException(status_code=400, detail="Insufficient virtual BTC balance.")
            user.btc_balance = Decimal(user.btc_balance) - quantity
            user.usd_balance = Decimal(user.usd_balance) + total

        payload = {
            "id": transaction_id,
            "user_id": user_id,
            "transaction_type": action,
            "btc_quantity": quantity,
            "price_usd": price,
            "total_usd": total,
            "timestamp": timestamp,
        }
        transaction_hash = hash_transaction(payload)
        ledger_record = {
            **payload,
            "timestamp": timestamp.isoformat(),
            "btc_quantity": format(quantity, "f"),
            "price_usd": format(price, "f"),
            "total_usd": format(total, "f"),
            "transaction_hash": transaction_hash,
        }
        chain = load_chain(db)
        block = chain.add_block([ledger_record])
        transaction = Transaction(
            id=transaction_id,
            user_id=user_id,
            transaction_type=action,
            btc_quantity=quantity,
            price_usd=price,
            total_usd=total,
            timestamp=timestamp,
            transaction_hash=transaction_hash,
            block_index=block.index,
            payload_json=canonical_json(ledger_record),
        )
        db.add(transaction)
        persist_block(db, block)
        record_audit(db, user_id, f"SIMULATED_{action}", {"transaction_id": transaction_id})
        db.commit()
        db.refresh(transaction)
    except HTTPException:
        db.rollback()
        raise
    except Exception:
        db.rollback()
        raise

    background_tasks.add_task(
        request.app.state.connection_manager.broadcast,
        {"type": "block_added", "block": public_block(block)},
    )
    return transaction


@router.post("/buy", response_model=TransactionResponse, status_code=201)
def buy(
    payload: TradeRequest,
    request: Request,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> Transaction:
    return _trade(request, background_tasks, db, user.id, payload.btc_quantity, "BUY")


@router.post("/sell", response_model=TransactionResponse, status_code=201)
def sell(
    payload: TradeRequest,
    request: Request,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> Transaction:
    return _trade(request, background_tasks, db, user.id, payload.btc_quantity, "SELL")


@router.get("/history", response_model=list[TransactionResponse])
def history(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> list[Transaction]:
    return db.scalars(
        select(Transaction).where(Transaction.user_id == user.id).order_by(Transaction.timestamp.desc())
    ).all()


@router.get("/portfolio")
def portfolio(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> dict[str, str | float]:
    return {
        "usd_balance": format(user.usd_balance, "f"),
        "btc_balance": format(user.btc_balance, "f"),
        "btc_price_usd": settings.demo_btc_price,
        "portfolio_value_usd": format(
            Decimal(user.usd_balance) + Decimal(user.btc_balance) * Decimal(str(settings.demo_btc_price)),
            "f",
        ),
    }
