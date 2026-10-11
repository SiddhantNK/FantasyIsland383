"""Deterministic demo dataset: 1 depot, 10 customers, 3 vehicles."""
from __future__ import annotations

import math

from .models import DEPOT, Order, Vehicle

COORDS = {
    DEPOT: (0, 0),
    "C01": (4, 3), "C02": (7, 1), "C03": (9, 5), "C04": (3, 8), "C05": (-3, 6),
    "C06": (-6, 2), "C07": (-4, -4), "C08": (2, -6), "C09": (8, -3), "C10": (-8, -6),
}


def demo_travel() -> dict:
    t = {}
    for a, (ax, ay) in COORDS.items():
        for b, (bx, by) in COORDS.items():
            if a != b:
                t[(a, b)] = max(3, round(math.hypot(ax - bx, ay - by) * 3))
    return t


def demo_vehicles() -> list:
    return [Vehicle("V01", 400, 3.0), Vehicle("V02", 400, 3.0), Vehicle("V03", 300, 2.5)]


def demo_orders() -> list:
    # (id, location, earliest, latest)
    spec = [
        ("O01", "C01", 480, 960), ("O02", "C02", 480, 960), ("O03", "C03", 540, 1020),
        ("O04", "C04", 480, 780), ("O05", "C05", 600, 1020), ("O06", "C06", 480, 960),
        ("O07", "C07", 540, 1020), ("O08", "C08", 480, 780), ("O09", "C09", 600, 1020),
        ("O10", "C10", 480, 1020),
    ]
    return [Order(i, loc, 100, 0.6, e, l, 10, 1) for i, loc, e, l in spec]
