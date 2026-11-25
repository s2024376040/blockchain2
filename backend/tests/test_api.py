from sqlalchemy import select

from app.database.session import SessionLocal
from app.models import User


def test_root_redirects_to_api_docs(client):
    response = client.get("/", follow_redirects=False)
    assert response.status_code == 307
    assert response.headers["location"] == "/docs"


def register_and_login(client, email="trader@example.com"):
    response = client.post(
        "/auth/register",
        json={"email": email, "password": "secure-password-123"},
    )
    assert response.status_code == 201
    login = client.post(
        "/auth/login",
        json={"email": email, "password": "secure-password-123"},
    )
    assert login.status_code == 200
    return {"Authorization": f"Bearer {login.json()['access_token']}"}


def test_register_trade_and_verify(client):
    headers = register_and_login(client)
    trade = client.post("/trading/buy", json={"btc_quantity": "0.25"}, headers=headers)
    assert trade.status_code == 201
    transaction = trade.json()

    result = client.post(
        "/blockchain/verify-transaction",
        json={"transaction_id": transaction["id"]},
        headers=headers,
    )
    assert result.status_code == 200
    assert result.json()["valid"] is True


def test_insufficient_virtual_balance_does_not_create_trade(client):
    headers = register_and_login(client, "poor@example.com")
    response = client.post("/trading/buy", json={"btc_quantity": "999999"}, headers=headers)
    assert response.status_code == 400
    assert client.get("/trading/history", headers=headers).json() == []


def test_tampering_simulation_leaves_committed_chain_unchanged(client):
    headers = register_and_login(client, "simulation@example.com")
    trade = client.post("/trading/buy", json={"btc_quantity": "0.1"}, headers=headers).json()
    before = client.get("/blockchain/blocks", headers=headers).json()

    result = client.post(
        "/blockchain/simulate-tampering",
        json={"transaction_id": trade["id"], "replacement_quantity": "0.9"},
        headers=headers,
    )
    after = client.get("/blockchain/blocks", headers=headers).json()

    assert result.status_code == 200
    simulation = result.json()
    assert simulation["original_chain_unchanged"] is True
    tampered_block = next(
        block
        for block in simulation["blocks"]
        if block["index"] == trade["block_index"]
    )
    committed_block = next(
        block for block in before if block["index"] == trade["block_index"]
    )
    assert tampered_block["block_hash"] != committed_block["block_hash"]
    assert tampered_block["merkle_root"] != committed_block["merkle_root"]
    assert before == after


def test_sell_updates_virtual_balances(client):
    headers = register_and_login(client, "seller@example.com")
    bought = client.post("/trading/buy", json={"btc_quantity": "0.25"}, headers=headers)
    assert bought.status_code == 201
    sold = client.post("/trading/sell", json={"btc_quantity": "0.1"}, headers=headers)
    assert sold.status_code == 201

    portfolio = client.get("/trading/portfolio", headers=headers).json()
    assert portfolio["btc_balance"] == "0.15000000"
    assert portfolio["usd_balance"] == "90250.00"


def test_invalid_verification_is_audited_and_admin_routes_are_protected(client):
    headers = register_and_login(client, "auditor@example.com")
    result = client.post(
        "/blockchain/verify-transaction",
        json={"transaction_id": "missing-transaction"},
        headers=headers,
    )
    assert result.status_code == 200
    assert result.json()["valid"] is False
    events = client.get("/audit/history", headers=headers).json()
    assert any(event["action"] == "INVALID_VERIFICATION_ATTEMPT" for event in events)
    assert client.get("/admin/dashboard", headers=headers).status_code == 403


def test_websocket_notifies_subscribers_after_trade(client):
    headers = register_and_login(client, "socket@example.com")
    token = headers["Authorization"].removeprefix("Bearer ")

    with client.websocket_connect(f"/ws/blockchain?token={token}") as websocket:
        response = client.post(
            "/trading/buy",
            json={"btc_quantity": "0.01"},
            headers=headers,
        )
        assert response.status_code == 201
        message = websocket.receive_json()

    assert message["type"] == "block_added"
    assert message["block"]["index"] == response.json()["block_index"]


def test_admin_dashboard_reports_integrity_metrics(client):
    headers = register_and_login(client, "admin@example.com")
    with SessionLocal() as db:
        user = db.scalar(select(User).where(User.email == "admin@example.com"))
        assert user is not None
        user.role = "admin"
        db.commit()

    response = client.get("/admin/dashboard", headers=headers)
    assert response.status_code == 200
    assert response.json()["valid_blocks"] >= 1
    assert response.json()["registered_users"] >= 1
