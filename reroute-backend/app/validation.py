"""Incident validation. Returns a list of human-readable errors ([] = valid)."""
from __future__ import annotations

from .models import EVENT_TYPES, ROAD_CLOSURE, URGENT_ORDER, VEHICLE_FAILURE


def _valid_time(t) -> bool:
    return isinstance(t, int) and 0 <= t < 24 * 60


def validate_incident(inc, vehicles, location_ids, orders, travel=None) -> list:
    errors = []
    vmap = {v.id: v for v in vehicles}
    locs = set(location_ids)

    if inc.event_type not in EVENT_TYPES:
        return [f"Unsupported incident type: {inc.event_type!r}."]
    if not _valid_time(inc.incident_time):
        errors.append("Incident time is missing or not a valid time of day.")

    if inc.event_type == VEHICLE_FAILURE:
        if not inc.vehicle_id:
            errors.append("Vehicle ID is required for a vehicle breakdown.")
        elif inc.vehicle_id not in vmap:
            errors.append(f"Unknown vehicle ID: {inc.vehicle_id}.")
        elif vmap[inc.vehicle_id].failed:
            errors.append(f"Duplicate report: {inc.vehicle_id} has already failed.")
        if inc.location_id and inc.location_id not in locs:
            errors.append(f"Unknown location: {inc.location_id}.")

    elif inc.event_type == ROAD_CLOSURE:
        for label, loc in (("From", inc.from_location), ("To", inc.to_location)):
            if not loc:
                errors.append(f"{label} location is required for a road closure.")
            elif loc not in locs:
                errors.append(f"Unknown location: {loc}.")
        if inc.from_location and inc.from_location == inc.to_location:
            errors.append("Road closure needs two different locations.")
        if (travel is not None and inc.from_location and inc.to_location
                and (inc.from_location, inc.to_location) not in travel
                and (inc.to_location, inc.from_location) not in travel):
            errors.append("No known road between these two locations.")
        if inc.end_time is not None and not _valid_time(inc.end_time):
            errors.append("Closure end time is not a valid time of day.")

    elif inc.event_type == URGENT_ORDER:
        o = inc.new_order
        if o is None:
            errors.append("Urgent order details are required.")
        else:
            if o.id in {x.id for x in orders}:
                errors.append(f"Duplicate order ID: {o.id}.")
            if o.location_id not in locs:
                errors.append(f"Unknown location: {o.location_id}.")
            if o.weight <= 0 or o.volume <= 0:
                errors.append("Order weight and volume must be positive.")
            if o.earliest > o.latest:
                errors.append("Order time window is invalid (earliest after latest).")
    return errors
