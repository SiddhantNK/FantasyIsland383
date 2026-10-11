"""In-memory repository: runs the whole backend without Supabase (dev/tests)."""
from __future__ import annotations

import copy
import itertools

from .demo_data import COORDS, demo_orders, demo_travel, demo_vehicles
from .models import DEPOT, Order, Plan, Vehicle


class MemoryRepo:
    def __init__(self):
        self.reset()

    # --- reference data
    def vehicles(self):
        return copy.deepcopy(list(self._vehicles.values()))

    def locations(self):
        return copy.deepcopy(self._locations)

    def orders(self):
        return copy.deepcopy(list(self._orders.values()))

    def travel(self):
        return dict(self._travel)

    def save_vehicles(self, vehicles):
        for v in vehicles:
            self._vehicles[v.id] = copy.deepcopy(v)

    def save_orders(self, orders):
        for o in orders:
            self._orders[o.id] = copy.deepcopy(o)

    # --- disruptions
    def add_disruption(self, row):
        row = dict(row, id=next(self._did), created_at="now")
        self._disruptions[row["id"]] = row
        return copy.deepcopy(row)

    def get_disruption(self, did):
        r = self._disruptions.get(did)
        return copy.deepcopy(r) if r else None

    def list_disruptions(self, status=None):
        rows = [r for r in self._disruptions.values() if status in (None, r["status"])]
        return copy.deepcopy(sorted(rows, key=lambda r: r["id"]))

    def update_disruption(self, did, fields):
        self._disruptions[did].update(fields)
        return copy.deepcopy(self._disruptions[did])

    # --- plans
    def save_plan(self, plan: Plan) -> Plan:
        plan.id = next(self._pid)
        self._plans[plan.id] = copy.deepcopy(plan)
        return plan

    def get_plan(self, plan_id):
        p = self._plans.get(plan_id)
        return copy.deepcopy(p) if p else None

    def latest_plan(self):
        return copy.deepcopy(self._plans[max(self._plans)]) if self._plans else None

    def list_plans(self):
        return [{"id": p.id, "version": p.version, "parent_plan_id": p.parent_plan_id,
                 "disruption_id": p.disruption_id, "feasible": p.feasible}
                for p in self._plans.values()]

    # --- history
    def add_history(self, row):
        row = dict(row, id=next(self._hid), created_at="now")
        self._history.append(row)

    def list_history(self):
        return copy.deepcopy(self._history)

    def reset(self):
        self._vehicles = {v.id: v for v in demo_vehicles()}
        self._orders = {o.id: o for o in demo_orders()}
        self._travel = demo_travel()
        self._locations = [
            {"id": k, "name": "Depot" if k == DEPOT else f"Customer {k}",
             "type": "DEPOT" if k == DEPOT else "CUSTOMER", "lat": y, "lng": x}
            for k, (x, y) in COORDS.items()]
        self._disruptions, self._plans, self._history = {}, {}, []
        self._did, self._pid, self._hid = itertools.count(1), itertools.count(1), itertools.count(1)
