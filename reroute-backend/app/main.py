"""FastAPI app. Run:  uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

Env: SUPABASE_URL, SUPABASE_KEY (service_role), REROUTE_ENGINE=ortools|greedy,
     REROUTE_REPO=memory to run without Supabase (demo data, resets on restart).
"""
from __future__ import annotations

import os
from typing import Optional

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

from fastapi import Depends, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from . import auth, service
from .parse_stub import parse_incident
from .replan import IncidentError


def make_repo():
    url, key = os.getenv("SUPABASE_URL"), os.getenv("SUPABASE_KEY")
    if os.getenv("REROUTE_REPO", "").lower() == "memory" or not (url and key):
        from .repo_memory import MemoryRepo
        return MemoryRepo()
    from .db import SupabaseRepo
    return SupabaseRepo(url, key)


repo = make_repo()
auth.bind_repo(repo)
ENGINE = os.getenv("REROUTE_ENGINE", "ortools")

app = FastAPI(title="ReRoute API")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

AuthUser = Depends(auth.get_user)
Dispatcher = Depends(auth.require_roles("DISPATCHER"))


@app.exception_handler(service.ServiceError)
async def _service_error(_, exc):
    return JSONResponse({"detail": exc.message}, status_code=exc.status)


@app.exception_handler(IncidentError)
async def _incident_error(_, exc):
    return JSONResponse({"detail": "Incident validation failed", "errors": exc.errors},
                        status_code=422)


class IncidentIn(BaseModel):
    event_type: str
    source: str = "FORM"               # FORM | AI_PARSER
    raw_text: Optional[str] = None
    vehicle_id: Optional[str] = None
    location_id: Optional[str] = None
    from_location: Optional[str] = None
    to_location: Optional[str] = None
    incident_time: Optional[str] = None   # "HH:MM"
    end_time: Optional[str] = None
    order: Optional[dict] = None          # urgent order payload


class ParseIn(BaseModel):
    text: str


class CorrectionsIn(BaseModel):
    corrections: dict


class ConfirmIn(BaseModel):
    corrections: Optional[dict] = None


class RegisterIn(BaseModel):
    email: str
    password: str
    name: str
    role: str = "DISPATCHER"
    vehicle_id: Optional[str] = None


class LoginIn(BaseModel):
    email: str
    password: str


def _dump(m):
    return m.model_dump() if hasattr(m, "model_dump") else m.dict()


def _auth_payload(user_row):
    user = auth.public_user(user_row)
    return {"token": auth.create_token(user), "user": user}


@app.get("/health")
def health():
    return {"ok": True, "engine": ENGINE, "repo": type(repo).__name__}


@app.post("/auth/register")
def auth_register(body: RegisterIn):
    auth.validate_register(body.email, body.password, body.name, body.role, body.vehicle_id)
    if body.vehicle_id and body.vehicle_id not in {v.id for v in repo.vehicles()}:
        raise HTTPException(422, f"Unknown vehicle {body.vehicle_id}")
    try:
        row = repo.create_user({
            "email": body.email,
            "name": body.name,
            "password_hash": auth.hash_password(body.password),
            "role": body.role,
            "vehicle_id": body.vehicle_id if body.role == "DRIVER" else None,
        })
    except ValueError as exc:
        raise HTTPException(409, str(exc)) from exc
    except Exception as exc:
        msg = str(exc).lower()
        if "duplicate" in msg or "unique" in msg:
            raise HTTPException(409, "Email already registered") from exc
        raise
    return _auth_payload(row)


@app.post("/auth/login")
def auth_login(body: LoginIn):
    row = repo.get_user_by_email(body.email)
    if row is None or not auth.verify_password(body.password, row["password_hash"]):
        raise HTTPException(401, "Invalid email or password")
    return _auth_payload(row)


@app.get("/auth/me")
def auth_me(user=AuthUser):
    return user


@app.get("/state")
def state(user=AuthUser):
    return service.get_state(repo)


# ---- plans
@app.post("/plans/initial")
def plans_initial(user=Dispatcher):
    return service.create_initial_plan(repo, engine=ENGINE)


@app.get("/plans")
def plans_list(user=AuthUser):
    return repo.list_plans()


@app.get("/plans/latest")
def plans_latest(user=AuthUser):
    plan = repo.latest_plan()
    if plan is None:
        raise HTTPException(404, "No plan yet")
    return service.plan_view(repo, plan)


@app.get("/plans/{plan_id}")
def plans_get(plan_id: int, user=AuthUser):
    plan = repo.get_plan(plan_id)
    if plan is None:
        raise HTTPException(404, f"Plan #{plan_id} not found")
    return service.plan_view(repo, plan)


@app.get("/plans/{plan_id}/compare")
def plans_compare(plan_id: int, user=AuthUser):
    """Compare a revised plan with the plan it was derived from."""
    return service.compare_with_parent(repo, plan_id)


# ---- incidents
@app.post("/incidents/parse")
def incidents_parse(body: ParseIn, user=AuthUser):
    """Free text -> structured preview (not stored). Needs the AI parser."""
    vids = [v.id for v in repo.vehicles()]
    lids = [l["id"] for l in repo.locations()]
    try:
        parsed = parse_incident(body.text, vids, lids)
    except NotImplementedError:
        raise HTTPException(501, "AI parser not connected yet")
    return service.preview_parsed(repo, parsed)


@app.post("/incidents")
def incidents_create(body: IncidentIn, user=AuthUser):
    """Both the form and the AI parser end up here (set `source`)."""
    payload = _dump(body)
    if user["role"] == "DRIVER" and user.get("vehicle_id"):
        if payload.get("event_type") == "VEHICLE_FAILURE":
            payload["vehicle_id"] = user["vehicle_id"]
    return service.submit_incident(repo, payload)


@app.get("/incidents")
def incidents_list(status: Optional[str] = None, user=AuthUser):
    return repo.list_disruptions(status.upper() if status else None)


@app.get("/incidents/{incident_id}")
def incidents_get(incident_id: int, user=AuthUser):
    row = repo.get_disruption(incident_id)
    if row is None:
        raise HTTPException(404, f"Incident #{incident_id} not found")
    return row


@app.patch("/incidents/{incident_id}")
def incidents_correct(incident_id: int, body: CorrectionsIn, user=Dispatcher):
    return service.update_incident(repo, incident_id, body.corrections)


@app.post("/incidents/{incident_id}/confirm")
def incidents_confirm(incident_id: int, body: Optional[ConfirmIn] = None, user=Dispatcher):
    corrections = body.corrections if body else None
    return service.confirm_incident(repo, incident_id, corrections, engine=ENGINE)


@app.post("/incidents/{incident_id}/reject")
def incidents_reject(incident_id: int, user=Dispatcher):
    return service.reject_incident(repo, incident_id)


# ---- history / admin
@app.get("/history")
def history(user=AuthUser):
    return repo.list_history()


@app.post("/admin/reset")
def admin_reset(user=Dispatcher):
    repo.reset()
    return {"ok": True}
