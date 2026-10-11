"""Supabase repository. Use the *service_role* key and keep it on the backend only."""
from __future__ import annotations

from .models import Order, Plan, Stop, Vehicle, to_min, to_time


class SupabaseRepo:
    def __init__(self, url: str, key: str):
        from supabase import create_client
        self.c = create_client(url, key)

    def _t(self, name):
        return self.c.table(name)

    # --- reference data
    def vehicles(self):
        out = []
        for r in self._t("vehicles").select("*").order("id").execute().data:
            failed = r["status"] == "FAILED"
            out.append(Vehicle(r["id"], float(r["weight_cap_kg"]), float(r["volume_cap_m3"]),
                               (to_min(r.get("failed_at")) or 0) if failed else None,
                               r.get("failed_location")))
        return out

    def locations(self):
        return self._t("locations").select("*").order("id").execute().data

    def orders(self):
        return [Order(r["id"], r["location_id"], float(r["weight_kg"]), float(r["volume_m3"]),
                      to_min(r["earliest"]), to_min(r["latest"]), int(r["service_min"]),
                      int(r["priority"]), r["status"])
                for r in self._t("orders").select("*").order("id").execute().data]

    def travel(self):
        rows = self._t("travel_times").select("from_id,to_id,minutes").execute().data
        return {(r["from_id"], r["to_id"]): int(r["minutes"]) for r in rows}

    def save_vehicles(self, vehicles):
        rows = [{"id": v.id, "weight_cap_kg": v.weight_cap, "volume_cap_m3": v.volume_cap,
                 "status": "FAILED" if v.failed else "ACTIVE",
                 "failed_at": to_time(v.failed_at), "failed_location": v.failed_location}
                for v in vehicles]
        if rows:
            self._t("vehicles").upsert(rows).execute()

    def save_orders(self, orders):
        rows = [{"id": o.id, "location_id": o.location_id, "weight_kg": o.weight,
                 "volume_m3": o.volume, "earliest": to_time(o.earliest),
                 "latest": to_time(o.latest), "service_min": o.service_min,
                 "priority": o.priority, "status": o.status} for o in orders]
        if rows:
            self._t("orders").upsert(rows).execute()

    # --- disruptions
    def add_disruption(self, row):
        return self._t("disruptions").insert(row).execute().data[0]

    def get_disruption(self, did):
        data = self._t("disruptions").select("*").eq("id", did).limit(1).execute().data
        return data[0] if data else None

    def list_disruptions(self, status=None):
        q = self._t("disruptions").select("*")
        if status:
            q = q.eq("status", status)
        return q.order("id").execute().data

    def update_disruption(self, did, fields):
        return self._t("disruptions").update(fields).eq("id", did).execute().data[0]

    # --- plans
    def save_plan(self, plan: Plan) -> Plan:
        meta = self._t("route_plans").insert({
            "version": plan.version, "parent_plan_id": plan.parent_plan_id,
            "disruption_id": plan.disruption_id, "feasible": plan.feasible}).execute().data[0]
        plan.id = meta["id"]
        rows = [{"plan_id": plan.id, "vehicle_id": s.vehicle_id, "order_id": s.order_id,
                 "seq": s.seq, "arrival": to_time(s.arrival), "wait_min": s.wait_min,
                 "departure": to_time(s.departure), "status": s.status, "reason": s.reason}
                for s in plan.stops]
        if rows:
            self._t("route_stops").insert(rows).execute()
        return plan

    def _load_plan(self, meta):
        rows = (self._t("route_stops").select("*").eq("plan_id", meta["id"])
                .order("seq").execute().data)
        stops = [Stop(r["vehicle_id"], r["order_id"], r["seq"],
                      self._loc_of(r["order_id"]), to_min(r.get("arrival")),
                      r.get("wait_min") or 0, to_min(r.get("departure")),
                      r["status"], r.get("reason")) for r in rows]
        return Plan(stops, meta["version"], meta["id"], meta.get("parent_plan_id"),
                    meta.get("disruption_id"), meta.get("feasible", True))

    def _loc_of(self, order_id):
        if not hasattr(self, "_order_loc") or order_id not in self._order_loc:
            self._order_loc = {o.id: o.location_id for o in self.orders()}
        return self._order_loc[order_id]

    def get_plan(self, plan_id):
        data = self._t("route_plans").select("*").eq("id", plan_id).limit(1).execute().data
        return self._load_plan(data[0]) if data else None

    def latest_plan(self):
        data = self._t("route_plans").select("*").order("id", desc=True).limit(1).execute().data
        return self._load_plan(data[0]) if data else None

    def list_plans(self):
        return self._t("route_plans").select("*").order("id").execute().data

    # --- history
    def add_history(self, row):
        self._t("replanning_history").insert(row).execute()

    def list_history(self):
        return self._t("replanning_history").select("*").order("id").execute().data

    # --- demo reset
    def reset(self):
        urgent = [d["details"]["order"]["id"] for d in self.list_disruptions()
                  if (d.get("details") or {}).get("order")]
        self._t("replanning_history").delete().gte("id", 0).execute()
        self._t("route_stops").delete().gte("id", 0).execute()
        self._t("route_plans").delete().gte("id", 0).execute()
        self._t("disruptions").delete().gte("id", 0).execute()
        for oid in urgent:
            self._t("orders").delete().eq("id", oid).execute()
        self._t("vehicles").update({"status": "ACTIVE", "failed_at": None,
                                    "failed_location": None}).neq("id", "").execute()
        self._t("orders").update({"status": "PENDING"}).neq("id", "").execute()
        self._order_loc = {}

    # --- users
    def get_user_by_email(self, email):
        key = (email or "").strip().lower()
        data = self._t("app_users").select("*").eq("email", key).limit(1).execute().data
        return data[0] if data else None

    def get_user_by_id(self, uid):
        if uid is None:
            return None
        data = self._t("app_users").select("*").eq("id", uid).limit(1).execute().data
        return data[0] if data else None

    def create_user(self, row):
        payload = {
            "email": row["email"].strip().lower(),
            "name": row["name"].strip(),
            "password_hash": row["password_hash"],
            "role": row["role"],
            "vehicle_id": row.get("vehicle_id"),
        }
        return self._t("app_users").insert(payload).execute().data[0]
