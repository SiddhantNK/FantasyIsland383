"""Plain data models shared by the solver, replanner and (later) the API.

All times are integer minutes since midnight (08:00 -> 480). Convert at the
edges with to_min() / hhmm() when reading/writing Supabase `time` columns.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Optional

DEPOT = "DEPOT"

VEHICLE_FAILURE = "VEHICLE_FAILURE"
ROAD_CLOSURE = "ROAD_CLOSURE"
URGENT_ORDER = "URGENT_ORDER"
EVENT_TYPES = {VEHICLE_FAILURE, ROAD_CLOSURE, URGENT_ORDER}


def to_min(value) -> Optional[int]:
    """'11:30' / '11:30:00' -> 690. Ints pass through, None stays None."""
    if value is None or isinstance(value, int):
        return value
    parts = str(value).split(":")
    return int(parts[0]) * 60 + int(parts[1])


def hhmm(minutes: Optional[int]) -> str:
    if minutes is None:
        return "--:--"
    return f"{minutes // 60:02d}:{minutes % 60:02d}"


@dataclass
class Vehicle:
    id: str
    weight_cap: float
    volume_cap: float
    failed_at: Optional[int] = None
    failed_location: Optional[str] = None

    @property
    def failed(self) -> bool:
        return self.failed_at is not None


@dataclass
class Order:
    id: str
    location_id: str
    weight: float
    volume: float
    earliest: int
    latest: int
    service_min: int = 10
    priority: int = 1  # higher = more important to keep in the plan
    status: str = "PENDING"  # PENDING | ASSIGNED | COMPLETED | UNASSIGNED


@dataclass
class Stop:
    """One row of route_stops. vehicle_id=None means the order is unassigned."""
    vehicle_id: Optional[str]
    order_id: str
    seq: int
    location_id: str
    arrival: Optional[int]
    wait_min: int
    departure: Optional[int]
    status: str = "PLANNED"  # PLANNED | COMPLETED | KEPT | MOVED | BROKEN
    reason: Optional[str] = None


@dataclass
class Plan:
    stops: list = field(default_factory=list)
    version: int = 1

    def route(self, vehicle_id: str) -> list:
        return sorted((s for s in self.stops if s.vehicle_id == vehicle_id),
                      key=lambda s: s.seq)

    def unassigned(self) -> list:
        return [s for s in self.stops if s.vehicle_id is None]

    def by_order(self) -> dict:
        return {s.order_id: s for s in self.stops}


@dataclass
class Incident:
    event_type: str
    incident_time: Optional[int] = None
    vehicle_id: Optional[str] = None
    location_id: Optional[str] = None
    from_location: Optional[str] = None
    to_location: Optional[str] = None
    end_time: Optional[int] = None
    new_order: Optional[Order] = None  # for URGENT_ORDER
    source: str = "FORM"  # FORM | AI_PARSER
    id: Optional[int] = None
