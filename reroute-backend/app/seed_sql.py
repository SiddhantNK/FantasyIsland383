"""Print SQL that loads the demo dataset:  python -m app.seed_sql > db/seed.sql"""
from __future__ import annotations

from .demo_data import COORDS, demo_orders, demo_travel, demo_vehicles
from .models import DEPOT, to_time


def main():
    out = ["-- ReRoute demo seed (3 vehicles, 10 orders)", ""]
    out.append("insert into locations (id, name, type, lat, lng) values")
    out.append(",\n".join(
        f"  ('{k}', '{'Depot' if k == DEPOT else 'Customer ' + k}', "
        f"'{'DEPOT' if k == DEPOT else 'CUSTOMER'}', {y}, {x})" for k, (x, y) in COORDS.items())
        + "\non conflict (id) do nothing;\n")
    out.append("insert into vehicles (id, weight_cap_kg, volume_cap_m3) values")
    out.append(",\n".join(f"  ('{v.id}', {v.weight_cap:g}, {v.volume_cap:g})"
                          for v in demo_vehicles()) + "\non conflict (id) do nothing;\n")
    out.append("insert into orders (id, location_id, weight_kg, volume_m3, earliest, latest, service_min, priority) values")
    out.append(",\n".join(
        f"  ('{o.id}', '{o.location_id}', {o.weight:g}, {o.volume:g}, "
        f"'{to_time(o.earliest)}', '{to_time(o.latest)}', {o.service_min}, {o.priority})"
        for o in demo_orders()) + "\non conflict (id) do nothing;\n")
    out.append("insert into travel_times (from_id, to_id, minutes) values")
    out.append(",\n".join(f"  ('{a}', '{b}', {m})" for (a, b), m in sorted(demo_travel().items()))
               + "\non conflict (from_id, to_id) do nothing;")
    print("\n".join(out))


if __name__ == "__main__":
    main()
