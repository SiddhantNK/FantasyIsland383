"""Placeholder for the Gemini-based free-text parser (teammate's work).

Contract the real implementation must follow:

    parse_incident(text, vehicle_ids, location_ids) -> dict

The dict uses the same keys as POST /incidents:
    event_type      VEHICLE_FAILURE | ROAD_CLOSURE | URGENT_ORDER
    vehicle_id, location_id, from_location, to_location   (known IDs only)
    incident_time, end_time                                "HH:MM"
    order           {id, location_id, weight_kg, volume_m3, earliest, latest,
                     service_min, priority}   (urgent orders only)
Plus optional:
    missing         list of field names it could not determine
    clarification   question to show the driver instead of guessing

It must never invent IDs. Values it is unsure about are left out / listed in
`missing`. Validation against the database happens in the backend afterwards.
"""
from __future__ import annotations


def parse_incident(text: str, vehicle_ids, location_ids) -> dict:
    raise NotImplementedError("AI parser not connected yet")
