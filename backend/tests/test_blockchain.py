from app.blockchain.engine import Blockchain, hash_transaction, verify_merkle_proof


def test_hash_and_merkle_inclusion_proof() -> None:
    transactions = [{"id": "a", "amount": "1"}, {"id": "b", "amount": "2"}, {"id": "c", "amount": "3"}]
    chain = Blockchain()
    block = chain.add_block(transactions)
    transaction_hashes = [hash_transaction(transaction) for transaction in transactions]

    assert chain.verify_chain()
    proof = chain.transaction_proof(transaction_hashes[1])
    assert proof is not None
    assert verify_merkle_proof(transaction_hashes[1], proof[1], block.merkle_root)

def test_hash_uses_canonical_key_order_and_validates_redundant_hash() -> None:
    chain = Blockchain()
    block = chain.add_block([{"id": "tx-1", "amount": "1"}])
    assert hash_transaction({"id": "tx-1", "amount": "1"}) == hash_transaction(
        {"amount": "1", "id": "tx-1"}
    )
    corrupted = type(block)(
        index=block.index,
        timestamp=block.timestamp,
        transactions=({"id": "tx-1", "amount": "1", "transaction_hash": "0" * 64},),
        previous_hash=block.previous_hash,
        merkle_root=block.merkle_root,
        block_hash=block.block_hash,
    )
    assert not chain.verify_block(corrupted)


def test_simulation_detects_tampering_without_changing_original_chain() -> None:
    chain = Blockchain()
    chain.add_block([{"id": "tx-1", "amount": "1"}])
    chain.add_block([{"id": "tx-2", "amount": "2"}])
    original = [(block.index, block.block_hash, block.previous_hash) for block in chain.blocks]

    simulated = chain.simulate_tampering("tx-1", {"id": "tx-1", "amount": "99"})

    assert simulated[1]["tampered"] is True
    assert simulated[2]["valid"] is False
    assert chain.verify_chain()
    assert original == [(block.index, block.block_hash, block.previous_hash) for block in chain.blocks]


def test_transaction_changes_are_detected() -> None:
    chain = Blockchain()
    original = chain.add_block([{"id": "tx-1", "amount": "1"}])
    tampered = type(original)(
        index=original.index,
        timestamp=original.timestamp,
        transactions=({"id": "tx-1", "amount": "99"},),
        previous_hash=original.previous_hash,
        merkle_root=original.merkle_root,
        block_hash=original.block_hash,
    )
    assert not chain.verify_block(tampered)


def test_block_and_transaction_views_cannot_mutate_committed_chain() -> None:
    chain = Blockchain()
    returned_block = chain.add_block([{"id": "tx-1", "amount": "1"}])
    returned_block.transactions[0]["amount"] = "99"
    exposed_blocks = chain.blocks
    exposed_blocks[1].transactions[0]["amount"] = "77"

    assert chain.verify_chain()
    assert chain.blocks[1].transactions[0]["amount"] == "1"
