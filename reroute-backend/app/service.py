"""Business workflow on top of a repository. main.py is a thin wrapper."""
from __future__ import annotations

import copy

from .models import (DEPOT, EVENT_TYPES, ROAD_CLOSURE, URGENT_ORDER, VEHICLE_FAILURE,
                     Incident, Order, hhmm, to_min, to_time)
from .replan import IncidentError, replan
from .solver import initial_plan
from .travel import apply_closures, missing_pairs
from .validation import validate_incident

FK_FIELDS = ("vehicle_id", "location_id", "from_location", "to_location")
PAYLOAD_FIELDS = ("event_type", "vehicle_id", "location_id", "from_location",
                  "to_location", "incident_time", "end_time", "order",
                  "raw_text", "source")


class ServiceError(Exception):
    def __init__(self, message, status=400):
        super().__init__(message)
        self.message, self.status = message, status


# ------------------------------------------------------------------ helpers
def _plan_orders_status(plan, orders):
    by = plan.by_order()
    for o in orders:
        s = by.get(o.id)
        if s is not None:
            o.status = ("COMPLETED" if s.status == "COMPLETED"
                        else "UNASSIGNED" if s.vehicle_id is None else "ASSIGNED")


def _stop_json(s, o=None):
    d = {"vehicle_id": s.vehicle_id, "order_id": s.order_id, "seq": s.seq,
         "location_id": s.location_id, "arrival": hhmm(s.arrival) if s.arrival is not None else None,
         "wait_min": s.wait_min,
         "departure": hhmm(s.departure) if s.departure is not None else None,
         "status": s.status, "reason": s.reason}
    if o:
        d.update(weight_kg=o.weight, volume_m3=o.volume,
                 window=f"{hhmm(o.earliest)}-{hhmm(o.latest)}",
                 priority=o.priority)
    return d


def plan_view(repo, plan) -> dict:
    omap = {o.id: o for o in repo.orders()}
    vehicles = []
    for v in repo.vehicles():
        route = plan.route(v.id)
        pending = [omap[s.order_id] for s in route if s.status != "COMPLETED"]
        wl, vl = sum(o.weight for o in pending), sum(o.volume for o in pending)
        vehicles.append({
            "id": v.id, "status": "FAILED" if v.failed else "ACTIVE",
            "failed_at": hhmm(v.failed_at) if v.failed else None,
            "weight_cap_kg": v.weight_cap, "volume_cap_m3": v.volume_cap,
            "pending_weight_kg": wl, "pending_volume_m3": vl,
            "weight_util_pct": round(100 * wl / v.weight_cap, 1) if v.weight_cap else 0,
            "volume_util_pct": round(100 * vl / v.volume_cap, 1) if v.volume_cap else 0,
            "stops": [_stop_json(s, omap.get(s.order_id)) for s in route]})
    return {"id": plan.id, "version": plan.version, "parent_plan_id": plan.parent_plan_id,
            "disruption_id": plan.disruption_id, "feasible": plan.feasible,
            "vehicles": vehicles,
            "unassigned": [_stop_json(s, omap.get(s.order_id)) for s in plan.unassigned()]}


def get_state(repo) -> dict:
    return {
        "vehicles": [{"id": v.id, "weight_cap_kg": v.weight_cap, "volume_cap_m3": v.volume_cap,
                      "status": "FAILED" if v.failed else "ACTIVE",
                      "failed_at": hhmm(v.failed_at) if v.failed else None} for v in repo.vehicles()],
        "orders": [{"id": o.id, "location_id": o.location_id, "weight_kg": o.weight,
                    "volume_m3": o.volume, "earliest": hhmm(o.earliest), "latest": hhmm(o.latest),
                    "service_min": o.service_min, "priority": o.priority, "status": o.status}
                   for o in repo.orders()],
        "locations": repo.locations()}


# -------------------------------------------------------------- initial plan
def create_initial_plan(repo, engine="ortools", time_limit_s=3) -> dict:
    if repo.latest_plan():
        raise ServiceError("A plan already exists. Reset first (POST /admin/reset).", 409)
    vehicles, travel = repo.vehicles(), repo.travel()
    orders = [o for o in repo.orders() if o.status != "COMPLETED"]
    if not travel:
        raise ServiceError("travel_times is empty - load the seed data first.", 500)
    used = sorted({DEPOT} | {o.location_id for o in orders})
    missing = missing_pairs(travel, used)
    if missing:
        raise ServiceError(f"travel_times is missing {len(missing)} pairs, e.g. {missing[0]}.", 500)
    plan = initial_plan(vehicles, orders, travel, engine=engine, time_limit_s=time_limit_s)
    plan.feasible = not plan.unassigned()
    repo.save_plan(plan)
    _plan_orders_status(plan, orders)
    repo.save_orders(orders)
    return plan_view(repo, plan)


# ---------------------------------------------------------------- incidents
def _build(repo, payload: dict):
    """payload -> (db row, Incident, errors). Raises IncidentError only for
    things that cannot even be stored (unknown event type / source)."""
    etype = payload.get("event_type")
    if etype not in EVENT_TYPES:
        raise IncidentError([f"Unsupported incident type: {etype!r}."])
    source = payload.get("source") or "FORM"
    if source not in ("FORM", "AI_PARSER"):
        raise IncidentError([f"Unknown report source: {source!r}."])

    errors = []

    def tm(key):
        v = payload.get(key)
        if v in (None, ""):
            return None
        try:
            return to_min(v)
        except (ValueError, IndexError, TypeError):
            errors.append(f"Invalid time for {key}: {v!r} (use HH:MM).")
            return None

    order, od = None, payload.get("order")
    if od:
        try:
            order = Order(id=str(od["id"]), location_id=od["location_id"],
                          weight=float(od["weight_kg"]), volume=float(od["volume_m3"]),
                          earliest=to_min(od["earliest"]), latest=to_min(od["latest"]),
                          service_min=int(od.get("service_min", 10)),
                          priority=int(od.get("priority", 1)))
        except (KeyError, TypeError, ValueError, IndexError) as e:
            errors.append(f"Invalid urgent order details: {e!r}.")

    inc = Incident(event_type=etype, incident_time=tm("incident_time"),
                   vehicle_id=payload.get("vehicle_id") or None,
                   location_id=payload.get("location_id") or None,
                   from_location=payload.get("from_location") or None,
                   to_location=payload.get("to_location") or None,
                   end_time=tm("end_time"), new_order=order, source=source)
    loc_ids = {l["id"] for l in repo.locations()}
    errors += validate_incident(inc, repo.vehicles(), loc_ids, repo.orders(), repo.travel())

    # FK columns can only hold known IDs; unknown ones are kept in details.
    known = {"vehicle_id": {v.id for v in repo.vehicles()}}
    row, unresolved = {}, {}
    for f in FK_FIELDS:
        val = getattr(inc, f)
        ok = val in (known.get(f) or loc_ids)
        row[f] = val if ok else None
        if val and not ok:
            unresolved[f] = val
    details = {}
    if od:
        details["order"] = od
    if unresolved:
        details["unresolved"] = unresolved
    row.update(source=source, raw_text=payload.get("raw_text"), event_type=etype,
               incident_time=to_time(inc.incident_time), end_time=to_time(inc.end_time),
               details=details or None)
    return row, inc, errors


def _row_to_payload(row) -> dict:
    d = row.get("details") or {}
    p = {k: row.get(k) for k in ("event_type", "raw_text", "source", "incident_time", "end_time")}
    for f in FK_FIELDS:
        p[f] = row.get(f) or (d.get("unresolved") or {}).get(f)
    p["order"] = d.get("order")
    return p


def _duplicates(repo, inc, exclude_id=None) -> list:
    out = []
    for d in repo.list_disruptions("PENDING"):
        if d["id"] == exclude_id or d["event_type"] != inc.event_type:
            continue
        p = _row_to_payload(d)
        if inc.event_type == VEHICLE_FAILURE:
            same = inc.vehicle_id is not None and p["vehicle_id"] == inc.vehicle_id
        elif inc.event_type == ROAD_CLOSURE:
            same = {p["from_location"], p["to_location"]} == {inc.from_location, inc.to_location}
        else:
            same = inc.new_order is not None and (p["order"] or {}).get("id") == inc.new_order.id
        if same:
            out.append(f"Duplicate of pending incident #{d['id']}.")
    return out


def submit_incident(repo, payload: dict) -> dict:
    row, inc, errors = _build(repo, payload)
    errors += _duplicates(repo, inc)
    row.update(validation_errors=errors, status="PENDING")
    return repo.add_disruption(row)


def preview_parsed(repo, parsed: dict) -> dict:
    try:
        _, _, errors = _build(repo, dict(parsed, source="AI_PARSER"))
    except IncidentError as e:
        errors = e.errors
    return {"parsed": parsed, "errors": errors,
            "missing": parsed.get("missing", []), "clarification": parsed.get("clarification")}


def _pending_row(repo, did):
    row = repo.get_disruption(did)
    if row is None:
        raise ServiceError(f"Incident #{did} not found.", 404)
    if row["status"] != "PENDING":
        raise ServiceError(f"Incident #{did} is already {row['status']}.", 409)
    return row


def _corrected(repo, row, corrections):
    payload = _row_to_payload(row)
    payload.update({k: v for k, v in (corrections or {}).items() if k in PAYLOAD_FIELDS})
    new_row, inc, errors = _build(repo, payload)
    errors += _duplicates(repo, inc, exclude_id=row["id"])
    new_row["validation_errors"] = errors
    return new_row, inc, errors


def update_incident(repo, did, corrections) -> dict:
    """Dispatcher edits an incident without confirming it."""
    row = _pending_row(repo, did)
    new_row, _, _ = _corrected(repo, row, corrections)
    new_row.pop("source", None)  # original report source never changes
    new_row.pop("raw_text", None)
    return repo.update_disruption(did, new_row)


def reject_incident(repo, did) -> dict:
    _pending_row(repo, did)
    return repo.update_disruption(did, {"status": "REJECTED"})


def effective_travel(repo, now) -> dict:
    """Base matrix plus every confirmed closure that is still in force at `now`."""
    closures = []
    for d in repo.list_disruptions("CONFIRMED"):
        if d["event_type"] != ROAD_CLOSURE:
            continue
        end = to_min(d.get("end_time"))
        extra = 60 if end is None else end - now
        if extra > 0:
            closures.append((d["from_location"], d["to_location"], extra))
    return apply_closures(repo.travel(), closures)


def confirm_incident(repo, did, corrections=None, engine="ortools", time_limit_s=3) -> dict:
    row = _pending_row(repo, did)
    new_row, inc, errors = _corrected(repo, row, corrections)
    if errors:
        repo.update_disruption(did, {k: v for k, v in new_row.items()
                                     if k not in ("source", "raw_text")})
        raise IncidentError(errors)
    plan = repo.latest_plan()
    if plan is None:
        raise ServiceError("No plan exists yet. Generate the initial plan first.", 409)

    res = replan(repo.vehicles(), repo.orders(), effective_travel(repo, inc.incident_time),
                 plan, inc, location_ids={l["id"] for l in repo.locations()},
                 engine=engine, time_limit_s=time_limit_s)

    res.plan.parent_plan_id, res.plan.disruption_id = plan.id, did
    res.plan.feasible = not res.plan.unassigned()
    repo.save_plan(res.plan)
    repo.save_orders(res.orders)
    repo.save_vehicles(res.vehicles)

    counts = {}
    for status, _ in res.changes.values():
        counts[status] = counts.get(status, 0) + 1
    summary = (f"{inc.event_type} at {hhmm(inc.incident_time)}: "
               + ", ".join(f"{n} {k.lower()}" for k, n in sorted(counts.items())))
    repo.add_history({"old_plan_id": plan.id, "new_plan_id": res.plan.id,
                      "disruption_id": did, "summary": summary})
    new_row["status"] = "CONFIRMED"
    new_row.pop("source", None)
    new_row.pop("raw_text", None)
    disruption = repo.update_disruption(did, new_row)
    return {"disruption": disruption, "summary": summary,
            "plan": plan_view(repo, res.plan),
            "changes": {k: {"status": s, "reason": r} for k, (s, r) in res.changes.items()}}


# ------------------------------------------------------------------- compare
def compare_with_parent(repo, plan_id) -> dict:
    new = repo.get_plan(plan_id)
    if new is None:
        raise ServiceError(f"Plan #{plan_id} not found.", 404)
    if new.parent_plan_id is None:
        raise ServiceError("This is the original plan; nothing to compare with.", 400)
    old = repo.get_plan(new.parent_plan_id)
    old_by = old.by_order()
    rows = []
    for s in sorted(new.stops, key=lambda s: s.order_id):
        o = old_by.get(s.order_id)
        rows.append({"order_id": s.order_id, "status": s.status, "reason": s.reason,
                     "old": _stop_json(o) if o else None, "new": _stop_json(s)})
    counts = {}
    for r in rows:
        counts[r["status"]] = counts.get(r["status"], 0) + 1
    return {"old_plan_id": old.id, "new_plan_id": new.id, "counts": counts, "orders": rows}
