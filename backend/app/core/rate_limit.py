import threading
import time

from fastapi import HTTPException, Request

_lock = threading.Lock()
_WINDOW_SECONDS = 60
_MAX_ATTEMPTS = 10


def enforce_sensitive_rate_limit(request: Request, endpoint: str) -> None:
    now = time.monotonic()
    key = (endpoint, request.client.host if request.client else "unknown")
    attempts: dict[tuple[str, str], list[float]] = request.app.state.rate_limit_attempts
    with _lock:
        recent = [timestamp for timestamp in attempts.get(key, []) if now - timestamp < _WINDOW_SECONDS]
        if len(recent) >= _MAX_ATTEMPTS:
            raise HTTPException(status_code=429, detail="Too many attempts. Please try again later.")
        recent.append(now)
        attempts[key] = recent
