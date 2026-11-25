import json
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.blockchain.engine import BlockData, Blockchain
from app.models import Block


def block_to_data(block: Block) -> BlockData:
    transactions = json.loads(block.transactions_json)
    return BlockData(
        index=block.index,
        timestamp=block.timestamp,
        transactions=tuple(transactions),
        previous_hash=block.previous_hash,
        merkle_root=block.merkle_root,
        block_hash=block.block_hash,
    )


def load_chain(db: Session) -> Blockchain:
    rows = db.scalars(select(Block).order_by(Block.index)).all()
    return Blockchain([block_to_data(row) for row in rows])


def persist_block(db: Session, block: BlockData) -> None:
    db.add(
        Block(
            index=block.index,
            timestamp=block.timestamp,
            previous_hash=block.previous_hash,
            merkle_root=block.merkle_root,
            block_hash=block.block_hash,
            transactions_json=json.dumps(block.transactions, sort_keys=True, separators=(",", ":")),
            transaction_hashes_json=json.dumps(
                [entry["transaction_hash"] for entry in block.transactions],
                separators=(",", ":"),
            ),
        )
    )


def public_block(block: BlockData) -> dict[str, Any]:
    return {
        "index": block.index,
        "timestamp": block.timestamp,
        "transactions": list(block.transactions),
        "transaction_count": len(block.transactions),
        "previous_hash": block.previous_hash,
        "merkle_root": block.merkle_root,
        "block_hash": block.block_hash,
    }
