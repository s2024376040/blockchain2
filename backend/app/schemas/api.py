from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=10, max_length=128)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)


class UserResponse(BaseModel):
    id: str
    email: EmailStr
    role: str

    model_config = ConfigDict(from_attributes=True)


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class TradeRequest(BaseModel):
    btc_quantity: Decimal = Field(gt=0, max_digits=20, decimal_places=8)


class TransactionResponse(BaseModel):
    id: str
    user_id: str
    transaction_type: str
    btc_quantity: Decimal
    price_usd: Decimal
    total_usd: Decimal
    timestamp: datetime
    transaction_hash: str
    block_index: int

    model_config = ConfigDict(from_attributes=True)


class VerifyRequest(BaseModel):
    transaction_id: str | None = None
    transaction_hash: str | None = None


class VerifyResponse(BaseModel):
    valid: bool
    reason: str
    transaction_id: str | None = None
    block_index: int | None = None
    proof: list[dict[str, str | int]] | None = None


class SimulationRequest(BaseModel):
    transaction_id: str
    replacement_quantity: Decimal = Field(gt=0, max_digits=20, decimal_places=8)


class SimulationResponse(BaseModel):
    original_chain_unchanged: bool
    tampered_block_index: int
    blocks: list[dict[str, object]]


class AuditResponse(BaseModel):
    id: int
    actor_user_id: str | None
    action: str
    details_json: str
    timestamp: datetime

    model_config = ConfigDict(from_attributes=True)
