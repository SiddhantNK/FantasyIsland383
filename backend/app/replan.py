"""Apply a confirmed incident and produce a revised plan.

Rules enforced here (deterministic, no AI involved):
  * completed stops are frozen exactly as they were,
  * a failed vehicle gets no stops after its failure time,
  * pending orders are re-solved with capacity + time-window constraints,
  * orders that cannot be placed are reported BROKEN with a reason.
"""
from __future__ import annotations

import copy
from dataclasses import dataclass

from .models import (DEPOT, ROAD_CLOSURE, URGENT_ORDER, VEHICLE_FAILURE,
                     Plan, hhmm)
from .solver import VehicleState, solve
from .travel import apply_closure
from .validation import validate_incident


class IncidentError(ValueError):
    def __init__(self, errors):
        super().__init__("; ".join(errors))
        self.errors = errors


@dataclass
class ReplanResult:
    plan: Plan
    vehicles: list
    orders: list
    travel: dict
    changes: dict  # order_id -> (status, reason)


def _is_done(stop, t, vehicle_failed) -> bool:
    """A stop is completed if already marked so, if service finished by t, or
    (for a healthy vehicle) if the vehicle is already at/serving the stop."""
    if stop.status == "COMPLETED":
        return True
    if stop.departure is not None and stop.departure <= t:
        return True
    return (not vehicle_failed) and stop.arrival is not None and stop.arrival <= t


def classify(old: Plan, new: Plan, incident, vehicles_before) -> dict:
    """Label every order Kept / Moved / Broken (or Completed) with a reason,
    and write the label onto the new plan's stops."""
    old_by = old.by_order()
    t = incident.incident_time
    failed_now = incident.vehicle_id if incident.event_type == VEHICLE_FAILURE else None
    result = {}
    for s in new.stops:
        prev = old_by.get(s.order_id)
        if s.status == "COMPLETED":
            result[s.order_id] = ("COMPLETED", "Already delivered; kept fixed.")
            continue
        if s.vehicle_id is None:
            base = s.reason or "Cannot be assigned."
            if prev and prev.vehicle_id and prev.vehicle_id == failed_now:
                base = (f"Was on {failed_now}, which failed at {hhmm(t)}. " + base)
            s.status, s.reason = "BROKEN", base
        elif prev is None:
            s.status = "MOVED"
            s.reason = f"New order inserted into {s.vehicle_id} at {hhmm(s.arrival)}."
        elif prev.vehicle_id is None:
            s.status = "MOVED"
            s.reason = f"Previously unassigned; now assigned to {s.vehicle_id}."
        elif prev.vehicle_id != s.vehicle_id:
            s.status = "MOVED"
            why = (f"{prev.vehicle_id} failed at {hhmm(t)}"
                   if prev.vehicle_id == failed_now else "re-optimized")
            s.reason = f"Reassigned from {prev.vehicle_id} to {s.vehicle_id} ({why})."
        elif (prev.seq, prev.arrival, prev.departure) != (s.seq, s.arrival, s.departure):
            s.status = "MOVED"
            s.reason = (f"Schedule changed on {s.vehicle_id}: arrival "
                        f"{hhmm(prev.arrival)} -> {hhmm(s.arrival)}, "
                        f"stop {prev.seq} -> {s.seq}.")
        else:
            s.status, s.reason = "KEPT", "Assignment and schedule unchanged."
        result[s.order_id] = (s.status, s.reason)
    return result


def replan(vehicles, orders, travel, plan: Plan, incident, location_ids=None,
           depot=DEPOT, shift_start=480, time_limit_s=2, engine="ortools",
           closure_default_min=60) -> ReplanResult:
    if location_ids is None:
        location_ids = {x for pair in travel for x in pair}
    errors = validate_incident(incident, vehicles, location_ids, orders, travel)
    if errors:
        raise IncidentError(errors)

    t = incident.incident_time
    vehicles = [copy.copy(v) for v in vehicles]
    vmap = {v.id: v for v in vehicles}
    omap = {o.id: copy.copy(o) for o in orders}
    travel = dict(travel)

    # 1. apply the disruption to the operational state
    if incident.event_type == VEHICLE_FAILURE:
        v = vmap[incident.vehicle_id]
        v.failed_at, v.failed_location = t, incident.location_id
    elif incident.event_type == ROAD_CLOSURE:
        if incident.end_time is None:
            extra = closure_default_min
        else:
            extra = max(incident.end_time - t, 0)  # blocked until it reopens
        if extra > 0:
            travel = apply_closure(travel, incident.from_location,
                                   incident.to_location, extra)
    elif incident.event_type == URGENT_ORDER:
        o = copy.copy(incident.new_order)
        o.status = "PENDING"
        omap[o.id] = o

    # 2. freeze completed stops, find where each healthy vehicle stands
    frozen, states = [], []
    for v in vehicles:
        done = []
        for s in plan.route(v.id):
            if _is_done(s, t, v.failed):
                done.append(s)
            else:
                break  # completed stops form a prefix of the route
        for s in done:
            fs = copy.copy(s)
            fs.status = "COMPLETED"
            frozen.append(fs)
        if not v.failed:
            if done:
                states.append(VehicleState(v, done[-1].location_id,
                                           done[-1].departure, len(done) + 1))
            else:
                states.append(VehicleState(v, depot, shift_start, 1))

    done_ids = {s.order_id for s in frozen}
    pending = [o for o in omap.values()
               if o.id not in done_ids and o.status != "COMPLETED"]

    # 3. re-solve everything still pending (never earlier than "now")
    solved = solve(states, pending, travel, not_before=t,
                   time_limit_s=time_limit_s, engine=engine)
    new_plan = Plan(stops=frozen + solved.stops, version=plan.version + 1)

    # 4. statuses + Kept/Moved/Broken classification
    changes = classify(plan, new_plan, incident, vehicles)
    for s in new_plan.stops:
        omap[s.order_id].status = ("COMPLETED" if s.status == "COMPLETED"
                                   else "UNASSIGNED" if s.vehicle_id is None
                                   else "ASSIGNED")
    return ReplanResult(new_plan, vehicles, list(omap.values()), travel, changes)
