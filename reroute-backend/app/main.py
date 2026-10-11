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

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from . import service
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
ENGINE = os.getenv("REROUTE_ENGINE", "ortools")

app = FastAPI(title="ReRoute API")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])


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


class VehicleIn(BaseModel):
    id: str
    weight_cap_kg: float
    volume_cap_m3: float


class ParseIn(BaseModel):
    text: str


class CorrectionsIn(BaseModel):
    corrections: dict


class ConfirmIn(BaseModel):
    corrections: Optional[dict] = None


def _dump(m):
    return m.model_dump() if hasattr(m, "model_dump") else m.dict()


@app.get("/health")
def health():
    return {"ok": True, "engine": ENGINE, "repo": type(repo).__name__}


@app.get("/state")
def state():
    return service.get_state(repo)


# ---- vehicles
@app.get("/vehicles")
def vehicles_list():
    return [{"id": v.id, "weight_cap_kg": v.weight_cap, "volume_cap_m3": v.volume_cap,
             "status": "FAILED" if v.failed else "ACTIVE",
             "failed_at": v.failed_at, "failed_location": v.failed_location}
            for v in repo.vehicles()]


@app.post("/vehicles")
def vehicles_add(body: VehicleIn):
    vid = body.id.strip().upper()
    if not vid:
        raise HTTPException(400, "Vehicle ID is required.")
    existing = {v.id for v in repo.vehicles()}
    if vid in existing:
        raise HTTPException(409, f"Vehicle {vid} already exists.")
    if body.weight_cap_kg <= 0 or body.volume_cap_m3 <= 0:
        raise HTTPException(400, "Capacity values must be positive.")
    from .models import Vehicle
    v = Vehicle(id=vid, weight_cap=body.weight_cap_kg, volume_cap=body.volume_cap_m3)
    repo.save_vehicles([v])
    return {"id": v.id, "weight_cap_kg": v.weight_cap, "volume_cap_m3": v.volume_cap,
            "status": "ACTIVE"}


@app.patch("/vehicles/{vehicle_id}")
def vehicles_update(vehicle_id: str, body: VehicleIn):
    vmap = {v.id: v for v in repo.vehicles()}
    if vehicle_id not in vmap:
        raise HTTPException(404, f"Vehicle {vehicle_id} not found.")
    v = vmap[vehicle_id]
    if body.weight_cap_kg > 0:
        v.weight_cap = body.weight_cap_kg
    if body.volume_cap_m3 > 0:
        v.volume_cap = body.volume_cap_m3
    repo.save_vehicles([v])
    return {"id": v.id, "weight_cap_kg": v.weight_cap, "volume_cap_m3": v.volume_cap,
            "status": "FAILED" if v.failed else "ACTIVE"}


@app.delete("/vehicles/{vehicle_id}")
def vehicles_delete(vehicle_id: str):
    vmap = {v.id: v for v in repo.vehicles()}
    if vehicle_id not in vmap:
        raise HTTPException(404, f"Vehicle {vehicle_id} not found.")
    plan = repo.latest_plan()
    if plan:
        active_stops = [s for s in plan.route(vehicle_id) if s.status not in ("COMPLETED", "BROKEN")]
        if active_stops:
            raise HTTPException(409, f"Vehicle {vehicle_id} has {len(active_stops)} active stops. "
                                     "Reset or complete the plan first.")
    repo.delete_vehicle(vehicle_id)
    return {"ok": True, "deleted": vehicle_id}


# ---- plans
@app.post("/plans/initial")
def plans_initial():
    return service.create_initial_plan(repo, engine=ENGINE)


@app.get("/plans")
def plans_list():
    return repo.list_plans()


@app.get("/plans/latest")
def plans_latest():
    plan = repo.latest_plan()
    if plan is None:
        raise HTTPException(404, "No plan yet")
    return service.plan_view(repo, plan)


@app.get("/plans/{plan_id}")
def plans_get(plan_id: int):
    plan = repo.get_plan(plan_id)
    if plan is None:
        raise HTTPException(404, f"Plan #{plan_id} not found")
    return service.plan_view(repo, plan)


@app.get("/plans/{plan_id}/compare")
def plans_compare(plan_id: int):
    """Compare a revised plan with the plan it was derived from."""
    return service.compare_with_parent(repo, plan_id)


# ---- incidents
@app.post("/incidents/parse")
def incidents_parse(body: ParseIn):
    """Free text -> structured preview (not stored). Needs the AI parser."""
    vids = [v.id for v in repo.vehicles()]
    lids = [l["id"] for l in repo.locations()]
    try:
        parsed = parse_incident(body.text, vids, lids)
    except NotImplementedError:
        raise HTTPException(501, "AI parser not connected yet")
    return service.preview_parsed(repo, parsed)


@app.post("/incidents")
def incidents_create(body: IncidentIn):
    """Both the form and the AI parser end up here (set `source`)."""
    return service.submit_incident(repo, _dump(body))


@app.get("/incidents")
def incidents_list(status: Optional[str] = None):
    return repo.list_disruptions(status.upper() if status else None)


@app.get("/incidents/{incident_id}")
def incidents_get(incident_id: int):
    row = repo.get_disruption(incident_id)
    if row is None:
        raise HTTPException(404, f"Incident #{incident_id} not found")
    return row


@app.patch("/incidents/{incident_id}")
def incidents_correct(incident_id: int, body: CorrectionsIn):
    return service.update_incident(repo, incident_id, body.corrections)


@app.post("/incidents/{incident_id}/confirm")
def incidents_confirm(incident_id: int, body: Optional[ConfirmIn] = None):
    corrections = body.corrections if body else None
    return service.confirm_incident(repo, incident_id, corrections, engine=ENGINE)


@app.post("/incidents/{incident_id}/reject")
def incidents_reject(incident_id: int):
    return service.reject_incident(repo, incident_id)


# ---- history / admin
@app.get("/history")
def history():
    return repo.list_history()


@app.post("/admin/reset")
def admin_reset():
    repo.reset()
    return {"ok": True}
