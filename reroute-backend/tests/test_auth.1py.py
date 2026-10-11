import time

import jwt
import pytest
from fastapi import Depends, FastAPI
from fastapi.testclient import TestClient

from app import auth

app = FastAPI()
app.include_router(auth.router)


@app.get("/only-dispatcher")
def only_dispatcher(user=Depends(auth.require_role("dispatcher"))):
    return user


@pytest.fixture(autouse=True)
def memory_mode(monkeypatch):
    monkeypatch.setenv("REROUTE_REPO", "memory")
    monkeypatch.setenv("DISPATCHER_INVITE_CODE", "letmein-123")
    auth._mem.clear()


client = TestClient(app)
NEW = {"name": "Asha", "email": "Asha@Example.com", "password": "longenough1"}


def bearer(token):
    return {"Authorization": f"Bearer {token}"}


def test_register_then_me_as_driver():
    r = client.post("/auth/register", json=NEW)
    assert r.status_code == 201
    assert r.json()["user"] == {"email": "asha@example.com", "name": "Asha", "role": "driver"}
    me = client.get("/auth/me", headers=bearer(r.json()["access_token"]))
    assert me.status_code == 200 and me.json()["role"] == "driver"


def test_duplicate_email_and_weak_password_rejected():
    assert client.post("/auth/register", json=NEW).status_code == 201
    assert client.post("/auth/register", json=NEW).status_code == 409
    weak = {**NEW, "email": "b@example.com", "password": "short"}
    assert client.post("/auth/register", json=weak).status_code == 422


def test_login_success_and_failure():
    client.post("/auth/register", json=NEW)
    ok = client.post("/auth/login", json={"email": "asha@example.com", "password": NEW["password"]})
    assert ok.status_code == 200 and "access_token" in ok.json()
    bad = client.post("/auth/login", json={"email": "asha@example.com", "password": "wrong-pass"})
    ghost = client.post("/auth/login", json={"email": "nobody@example.com", "password": "wrong-pass"})
    assert bad.status_code == ghost.status_code == 401
    assert bad.json() == ghost.json()  # no hint about which emails exist


def test_demo_logins_in_memory_mode():
    r = client.post("/auth/login", json={"email": "dispatcher@reroute.local", "password": "password123"})
    assert r.status_code == 200 and r.json()["user"]["role"] == "dispatcher"


def test_invite_code_controls_dispatcher_role():
    bad = client.post("/auth/register", json={**NEW, "invite_code": "guess"})
    assert bad.status_code == 403
    good = client.post("/auth/register", json={**NEW, "invite_code": "letmein-123"})
    assert good.json()["user"]["role"] == "dispatcher"


def test_role_guard_and_token_checks():
    driver = client.post("/auth/register", json=NEW).json()["access_token"]
    assert client.get("/only-dispatcher").status_code == 401
    assert client.get("/only-dispatcher", headers=bearer(driver)).status_code == 403

    boss = client.post("/auth/login", json={"email": "dispatcher@reroute.local",
                                            "password": "password123"}).json()["access_token"]
    assert client.get("/only-dispatcher", headers=bearer(boss)).status_code == 200

    forged = jwt.encode({"sub": "x@y.z", "name": "X", "role": "dispatcher",
                         "exp": int(time.time()) + 60}, "wrong-secret", algorithm="HS256")
    expired = jwt.encode({"sub": "x@y.z", "name": "X", "role": "dispatcher",
                          "exp": int(time.time()) - 5}, auth.SECRET, algorithm="HS256")
    assert client.get("/auth/me", headers=bearer(forged)).status_code == 401
    assert client.get("/auth/me", headers=bearer(expired)).status_code == 401


def test_login_page_is_served():
    r = client.get("/login")
    assert r.status_code == 200 and "ReRoute" in r.text
