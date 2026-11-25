import copy
import hashlib
import json
from dataclasses import dataclass
from datetime import datetime, timezone
from decimal import Decimal
from enum import Enum
from typing import Any


def canonical_json(value: Any) -> str:
    def normalize(item: Any) -> Any:
        if isinstance(item, Decimal):
            return format(item, "f")
        if isinstance(item, datetime):
            return item.astimezone(timezone.utc).isoformat()
        if isinstance(item, Enum):
            return item.value
        raise TypeError(f"Unsupported value in canonical JSON: {type(item).__name__}")

    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True, default=normalize)


def sha256_hex(value: str | bytes) -> str:
    encoded = value.encode("utf-8") if isinstance(value, str) else value
    return hashlib.sha256(encoded).hexdigest()


def hash_transaction(transaction: dict[str, Any]) -> str:
    payload = {key: value for key, value in transaction.items() if key != "transaction_hash"}
    return sha256_hex(canonical_json(payload))


def merkle_root(transaction_hashes: list[str]) -> str:
    if not transaction_hashes:
        return sha256_hex(b"")

    level = [bytes.fromhex(value) for value in transaction_hashes]
    while len(level) > 1:
        if len(level) % 2:
            level.append(level[-1])
        level = [
            hashlib.sha256(level[index] + level[index + 1]).digest()
            for index in range(0, len(level), 2)
        ]
    return level[0].hex()


def merkle_proof(transaction_hashes: list[str], transaction_index: int) -> list[dict[str, str | int]]:
    if transaction_index < 0 or transaction_index >= len(transaction_hashes):
        raise IndexError("Transaction index is outside the block.")
    proof: list[dict[str, str | int]] = []
    level = [bytes.fromhex(value) for value in transaction_hashes]
    position = transaction_index
    while len(level) > 1:
        if len(level) % 2:
            level.append(level[-1])
        sibling_index = position - 1 if position % 2 else position + 1
        proof.append(
            {
                "hash": level[sibling_index].hex(),
                "side": "left" if sibling_index < position else "right",
            }
        )
        level = [
            hashlib.sha256(level[index] + level[index + 1]).digest()
            for index in range(0, len(level), 2)
        ]
        position //= 2
    return proof


def verify_merkle_proof(transaction_hash: str, proof: list[dict[str, str | int]], root: str) -> bool:
    current = bytes.fromhex(transaction_hash)
    for item in proof:
        sibling = bytes.fromhex(str(item["hash"]))
        current = (
            hashlib.sha256(sibling + current).digest()
            if item["side"] == "left"
            else hashlib.sha256(current + sibling).digest()
        )
    return current.hex() == root


@dataclass(frozen=True)
class BlockData:
    index: int
    timestamp: str
    transactions: tuple[dict[str, Any], ...]
    previous_hash: str
    merkle_root: str
    block_hash: str


class Blockchain:
    def __init__(self, blocks: list[BlockData] | None = None) -> None:
        initial_blocks = copy.deepcopy(blocks or [])
        if not initial_blocks:
            initial_blocks.append(self.create_block(0, [], "0" * 64))
        self._blocks = tuple(initial_blocks)

    @property
    def blocks(self) -> tuple[BlockData, ...]:
        return copy.deepcopy(self._blocks)

    @staticmethod
    def _block_hash(index: int, timestamp: str, transactions: list[dict[str, Any]], previous_hash: str) -> str:
        hashes = [hash_transaction(transaction) for transaction in transactions]
        data = {
            "index": index,
            "timestamp": timestamp,
            "transaction_hashes": hashes,
            "previous_hash": previous_hash,
            "merkle_root": merkle_root(hashes),
        }
        return sha256_hex(canonical_json(data))

    @classmethod
    def create_block(
        cls, index: int, transactions: list[dict[str, Any]], previous_hash: str
    ) -> BlockData:
        timestamp = datetime.now(timezone.utc).isoformat()
        hashes = [hash_transaction(transaction) for transaction in transactions]
        return BlockData(
            index=index,
            timestamp=timestamp,
            transactions=tuple(copy.deepcopy(transactions)),
            previous_hash=previous_hash,
            merkle_root=merkle_root(hashes),
            block_hash=cls._block_hash(index, timestamp, transactions, previous_hash),
        )

    def add_block(self, transactions: list[dict[str, Any]]) -> BlockData:
        previous = self._blocks[-1]
        block = self.create_block(previous.index + 1, transactions, previous.block_hash)
        self._blocks = (*self._blocks, block)
        return copy.deepcopy(block)

    def verify_block(self, block: BlockData) -> bool:
        transactions = list(block.transactions)
        hashes = [hash_transaction(transaction) for transaction in transactions]
        transaction_hashes_match = all(
            transaction.get("transaction_hash", transaction_hash) == transaction_hash
            for transaction, transaction_hash in zip(transactions, hashes)
        )
        return (
            transaction_hashes_match
            and block.merkle_root == merkle_root(hashes)
            and block.block_hash
            == self._block_hash(block.index, block.timestamp, transactions, block.previous_hash)
        )

    def verify_block_link(self, position: int) -> bool:
        if position < 0 or position >= len(self._blocks):
            return False
        expected_previous = "0" * 64 if position == 0 else self._blocks[position - 1].block_hash
        block = self._blocks[position]
        return block.index == position and block.previous_hash == expected_previous

    def verify_chain(self) -> bool:
        for index, block in enumerate(self._blocks):
            if not self.verify_block(block) or not self.verify_block_link(index):
                return False
        return bool(self._blocks)

    def transaction_proof(self, transaction_hash: str) -> tuple[BlockData, list[dict[str, str | int]]] | None:
        for block in self._blocks:
            hashes = [hash_transaction(transaction) for transaction in block.transactions]
            if transaction_hash in hashes:
                index = hashes.index(transaction_hash)
                return block, merkle_proof(hashes, index)
        return None

    def simulate_tampering(
        self, transaction_id: str, replacement: dict[str, Any]
    ) -> list[dict[str, object]]:
        temporary = list(copy.deepcopy(self._blocks))
        target_block_index = -1
        for position, block in enumerate(temporary):
            transactions = [copy.deepcopy(transaction) for transaction in block.transactions]
            for transaction_position, transaction in enumerate(transactions):
                if transaction.get("id") == transaction_id:
                    transactions[transaction_position] = replacement
                    target_block_index = position
                    break
            if target_block_index >= 0:
                hashes = [hash_transaction(tx) for tx in transactions]
                temporary[position] = BlockData(
                    index=block.index,
                    timestamp=block.timestamp,
                    transactions=tuple(transactions),
                    previous_hash=block.previous_hash,
                    merkle_root=merkle_root(hashes),
                    block_hash=self._block_hash(block.index, block.timestamp, transactions, block.previous_hash),
                )
                break
        if target_block_index < 0:
            raise KeyError(f"Transaction {transaction_id} was not found in the ledger.")

        results: list[dict[str, object]] = []
        for position, block in enumerate(temporary):
            previous_is_valid = position == 0 or block.previous_hash == temporary[position - 1].block_hash
            tampered = position == target_block_index or not previous_is_valid
            valid = self.verify_block(block) and previous_is_valid and not tampered
            results.append(
                {
                    "index": block.index,
                    "block_hash": block.block_hash,
                    "previous_hash": block.previous_hash,
                    "merkle_root": block.merkle_root,
                    "valid": valid,
                    "tampered": tampered,
                }
            )
        return results
