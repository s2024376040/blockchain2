import json
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.dependencies import get_current_user
from app.blockchain.engine import Blockchain, hash_transaction, verify_merkle_proof
from app.database.session import get_db
from app.models import Block, Transaction, User
from app.schemas.api import SimulationRequest, SimulationResponse, VerifyRequest, VerifyResponse
from app.services.audit import record_audit
from app.services.ledger import load_chain, public_block

router = APIRouter(prefix="/blockchain", tags=["blockchain"])


@router.get("/blocks")
def blocks(db: Session = Depends(get_db), _: User = Depends(get_current_user)) -> list[dict[str, object]]:
    chain = load_chain(db)
    return [
        {**public_block(block), "valid": chain.verify_block(block) and chain.verify_block_link(position)}
        for position, block in enumerate(chain.blocks)
    ]


@router.get("/blocks/{block_id}")
def get_block(
    block_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
) -> dict[str, object]:
    row = db.get(Block, block_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Block not found.")
    chain = load_chain(db)
    block = next(item for item in chain.blocks if item.index == block_id)
    return {
        **public_block(block),
        "valid": chain.verify_block(block) and chain.verify_block_link(block_id),
    }


@router.get("/verify")
def verify_chain(db: Session = Depends(get_db), _: User = Depends(get_current_user)) -> dict[str, object]:
    chain = load_chain(db)
    return {"valid": chain.verify_chain(), "block_count": len(chain.blocks)}


@router.post("/verify-transaction", response_model=VerifyResponse)
def verify_transaction(
    payload: VerifyRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> VerifyResponse:
    if not payload.transaction_id and not payload.transaction_hash:
        raise HTTPException(status_code=422, detail="Provide a transaction ID or transaction hash.")
    query = select(Transaction)
    if payload.transaction_id:
        query = query.where(Transaction.id == payload.transaction_id)
    else:
        query = query.where(Transaction.transaction_hash == payload.transaction_hash)
    transaction = db.scalar(query)
    if transaction is None:
        reason = "Transaction is not recorded on the ledger."
        record_audit(
            db,
            user.id,
            "INVALID_VERIFICATION_ATTEMPT",
            {"transaction_id": payload.transaction_id, "transaction_hash": payload.transaction_hash, "reason": reason},
        )
        db.commit()
        return VerifyResponse(valid=False, reason=reason)

    chain = load_chain(db)
    match = chain.transaction_proof(transaction.transaction_hash)
    if match is None:
        return VerifyResponse(
            valid=False, reason="Transaction exists in the database but is absent from the blockchain."
        )
    block, proof = match
    correct_hash = hash_transaction(json.loads(transaction.payload_json)) == transaction.transaction_hash
    valid = correct_hash and verify_merkle_proof(transaction.transaction_hash, proof, block.merkle_root)
    valid = valid and chain.verify_chain()
    reason = (
        "Transaction inclusion and chain integrity verified."
        if valid
        else "Hash, Merkle proof, or chain integrity check failed."
    )
    record_audit(
        db,
        user.id,
        "TRANSACTION_VERIFICATION" if valid else "INVALID_VERIFICATION_ATTEMPT",
        {"transaction_id": transaction.id, "block_index": block.index, "valid": valid, "reason": reason},
    )
    db.commit()
    return VerifyResponse(
        valid=valid,
        reason=reason,
        transaction_id=transaction.id,
        block_index=block.index,
        proof=proof,
    )


@router.get("/merkle/{transaction_id}")
def merkle_proof(
    transaction_id: str,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
) -> dict[str, object]:
    transaction = db.get(Transaction, transaction_id)
    if transaction is None:
        raise HTTPException(status_code=404, detail="Transaction not found.")
    match = load_chain(db).transaction_proof(transaction.transaction_hash)
    if match is None:
        raise HTTPException(status_code=404, detail="Transaction is not included in a committed block.")
    block, proof = match
    return {
        "transaction_hash": transaction.transaction_hash,
        "block_index": block.index,
        "merkle_root": block.merkle_root,
        "proof": proof,
        "valid": verify_merkle_proof(transaction.transaction_hash, proof, block.merkle_root),
    }


@router.post("/simulate-tampering", response_model=SimulationResponse)
def simulate_tampering(
    payload: SimulationRequest,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
) -> SimulationResponse:
    transaction = db.get(Transaction, payload.transaction_id)
    if transaction is None:
        raise HTTPException(status_code=404, detail="Transaction not found.")
    ledger_before = [(row.index, row.block_hash) for row in db.scalars(select(Block).order_by(Block.index)).all()]
    replacement = json.loads(transaction.payload_json)
    replacement["btc_quantity"] = format(
        Decimal(payload.replacement_quantity).quantize(Decimal("0.00000001")), "f"
    )
    result = load_chain(db).simulate_tampering(transaction.id, replacement)
    ledger_after = [(row.index, row.block_hash) for row in db.scalars(select(Block).order_by(Block.index)).all()]
    return SimulationResponse(
        original_chain_unchanged=ledger_before == ledger_after,
        tampered_block_index=transaction.block_index,
        blocks=result,
    )
