"""Auth: hashing, JWT, register/login, and role guards."""
import os

os.environ["REROUTE_REPO"] = "memory"
os.environ["AUTH_SECRET"] = "test-secret-must-be-at-least-32b"

from fastapi.testclient import TestClient

from app import auth
from app.main import app
from app.repo_memory import MemoryRepo


client = TestClient(app)


def test_password_roundtrip():
    hashed = auth.hash_password("secret123")
    assert hashed.startswith("pbkdf2$")
    assert auth.verify_password("secret123", hashed)
    assert not auth.verify_password("nope", hashed)


def test_token_roundtrip():
    token = auth.create_token({"id": 7, "email": "a@b.com", "role": "DRIVER", "vehicle_id": "V01"})
    payload = auth.decode_token(token)
    assert payload["sub"] == "7"
    assert payload["role"] == "DRIVER"


def test_memory_seed_users():
    repo = MemoryRepo()
    disp = repo.get_user_by_email("dispatcher@reroute.local")
    drv = repo.get_user_by_email("driver@reroute.local")
    assert disp["role"] == "DISPATCHER"
    assert drv["role"] == "DRIVER" and drv["vehicle_id"] == "V01"
    assert auth.verify_password("password123", disp["password_hash"])


def test_login_demo_dispatcher():
    res = client.post("/auth/login", json={
        "email": "dispatcher@reroute.local",
        "password": "password123",
    })
    assert res.status_code == 200
    body = res.json()
    assert body["user"]["role"] == "DISPATCHER"
    assert body["token"]


def test_login_rejects_bad_password():
    res = client.post("/auth/login", json={
        "email": "dispatcher@reroute.local",
        "password": "wrong",
    })
    assert res.status_code == 401


def test_register_and_me():
    res = client.post("/auth/register", json={
        "email": "new.driver@reroute.local",
        "password": "secret123",
        "name": "Sam",
        "role": "DRIVER",
        "vehicle_id": "V02",
    })
    assert res.status_code == 200, res.text
    token = res.json()["token"]
    me = client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert me.status_code == 200
    assert me.json()["email"] == "new.driver@reroute.local"
    assert me.json()["vehicle_id"] == "V02"


def test_duplicate_register():
    payload = {
        "email": "dup@reroute.local",
        "password": "secret123",
        "name": "Dup",
        "role": "DISPATCHER",
    }
    assert client.post("/auth/register", json=payload).status_code == 200
    assert client.post("/auth/register", json=payload).status_code == 409


def test_protected_routes_need_token():
    assert client.get("/state").status_code == 401
    assert client.post("/plans/initial").status_code == 401


def test_driver_cannot_reset_or_plan():
    login = client.post("/auth/login", json={
        "email": "driver@reroute.local",
        "password": "password123",
    })
    headers = {"Authorization": f"Bearer {login.json()['token']}"}
    assert client.get("/state", headers=headers).status_code == 200
    assert client.post("/plans/initial", headers=headers).status_code == 403
    assert client.post("/admin/reset", headers=headers).status_code == 403


def test_dispatcher_can_create_plan():
    login = client.post("/auth/login", json={
        "email": "dispatcher@reroute.local",
        "password": "password123",
    })
    headers = {"Authorization": f"Bearer {login.json()['token']}"}
    client.post("/admin/reset", headers=headers)
    res = client.post("/plans/initial", headers=headers)
    assert res.status_code == 200
    assert res.json()["version"] == 1
