import json
from typing import Any

from sqlalchemy.orm import Session

from app.models import AuditEvent


def record_audit(
    db: Session, actor_user_id: str | None, action: str, details: dict[str, Any]
) -> None:
    db.add(
        AuditEvent(
            actor_user_id=actor_user_id,
            action=action,
            details_json=json.dumps(details, sort_keys=True, separators=(",", ":")),
        )
    )
