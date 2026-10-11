"""Password hashing, JWTs, and FastAPI auth dependencies."""
from __future__ import annotations

import base64
import hashlib
import hmac
import os
import time
from typing import Optional

from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

try:
    import jwt
except ImportError:  # pragma: no cover
    jwt = None

ROLES = {"DRIVER", "DISPATCHER"}
_ITERATIONS = 120_000
_bearer = HTTPBearer(auto_error=False)


def auth_secret() -> str:
    return os.getenv("AUTH_SECRET", "reroute-dev-secret-change-me")


def public_user(row: dict) -> dict:
    return {
        "id": row["id"],
        "email": row["email"],
        "name": row["name"],
        "role": row["role"],
        "vehicle_id": row.get("vehicle_id"),
    }


def hash_password(password: str) -> str:
    salt = os.urandom(16)
    dk = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, _ITERATIONS)
    return "pbkdf2$%s$%s" % (
        base64.b64encode(salt).decode("ascii"),
        base64.b64encode(dk).decode("ascii"),
    )


def verify_password(password: str, stored: str) -> bool:
    try:
        kind, salt_b64, hash_b64 = stored.split("$", 2)
    except ValueError:
        return False
    if kind != "pbkdf2":
        return False
    salt = base64.b64decode(salt_b64.encode("ascii"))
    expected = base64.b64decode(hash_b64.encode("ascii"))
    actual = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, _ITERATIONS)
    return hmac.compare_digest(actual, expected)


def create_token(user: dict, ttl_seconds: int = 60 * 60 * 24 * 7) -> str:
    if jwt is None:
        raise RuntimeError("PyJWT is required: pip install PyJWT")
    now = int(time.time())
    payload = {
        "sub": str(user["id"]),
        "email": user["email"],
        "role": user["role"],
        "vehicle_id": user.get("vehicle_id"),
        "iat": now,
        "exp": now + ttl_seconds,
    }
    return jwt.encode(payload, auth_secret(), algorithm="HS256")


def decode_token(token: str) -> dict:
    if jwt is None:
        raise RuntimeError("PyJWT is required: pip install PyJWT")
    try:
        return jwt.decode(token, auth_secret(), algorithms=["HS256"])
    except jwt.ExpiredSignatureError as exc:
        raise HTTPException(401, "Token expired") from exc
    except jwt.InvalidTokenError as exc:
        raise HTTPException(401, "Invalid token") from exc


def validate_register(email: str, password: str, name: str, role: str,
                      vehicle_id: Optional[str]) -> None:
    email = (email or "").strip()
    if "@" not in email or "." not in email.split("@")[-1]:
        raise HTTPException(422, "Enter a valid email address")
    if not name or not name.strip():
        raise HTTPException(422, "Name is required")
    if not password or len(password) < 6:
        raise HTTPException(422, "Password must be at least 6 characters")
    if role not in ROLES:
        raise HTTPException(422, "Role must be DRIVER or DISPATCHER")
    if role == "DRIVER" and not vehicle_id:
        raise HTTPException(422, "Drivers must pick a vehicle (V01, V02, or V03)")


def current_user(repo, creds: Optional[HTTPAuthorizationCredentials]):
    if creds is None or not creds.credentials:
        raise HTTPException(401, "Not authenticated")
    payload = decode_token(creds.credentials)
    user = repo.get_user_by_id(payload.get("sub"))
    if user is None:
        raise HTTPException(401, "User no longer exists")
    return public_user(user)


def require_roles(*roles):
    allowed = set(roles)

    def dependency(user: dict = Depends(get_user)):
        if user["role"] not in allowed:
            raise HTTPException(403, "This action requires %s access" % " or ".join(sorted(allowed)))
        return user

    return dependency


# Bound in main.py so dependencies can reach the live repo without circular imports.
_repo = None


def bind_repo(repo) -> None:
    global _repo
    _repo = repo


def get_user(creds: Optional[HTTPAuthorizationCredentials] = Depends(_bearer)):
    if _repo is None:
        raise HTTPException(500, "Auth is not initialized")
    return current_user(_repo, creds)
