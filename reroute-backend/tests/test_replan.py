from app.demo_data import demo_orders, demo_travel, demo_vehicles
from app.models import (DEPOT, ROAD_CLOSURE, URGENT_ORDER, VEHICLE_FAILURE,
                        Incident, Order, Vehicle)
from app.replan import IncidentError, replan
from app.solver import check_plan, initial_plan

try:
    import ortools  # noqa: F401
    ENGINES = ["greedy", "ortools"]
except ImportError:
    ENGINES = ["greedy"]

TRI = {(DEPOT, "A"): 10, ("A", DEPOT): 10, ("A", "B"): 10, ("B", "A"): 10,
       (DEPOT, "B"): 20, ("B", DEPOT): 20}


def test_breakdown_freezes_completed_and_blocks_failed_vehicle():
    for engine in ENGINES:
        vs, os_, tr = demo_vehicles(), demo_orders(), demo_travel()
        plan = initial_plan(vs, os_, tr, engine=engine)
        victim = max(vs, key=lambda v: len(plan.route(v.id))).id
        route = plan.route(victim)
        assert len(route) >= 2
        t = route[0].departure  # first stop finished, rest still pending
        inc = Incident(VEHICLE_FAILURE, t, vehicle_id=victim, location_id="C01")
        res = replan(vs, os_, tr, plan, inc, engine=engine)

        new_by = res.plan.by_order()
        # every order appears exactly once
        assert sorted(s.order_id for s in res.plan.stops) == sorted(o.id for o in os_)
        # failed vehicle: only completed stops, none after failure time
        for s in res.plan.route(victim):
            assert s.status == "COMPLETED" and s.departure <= t, engine
        # stops done before t are unchanged
        for old in plan.stops:
            done = (old.departure <= t if old.vehicle_id == victim
                    else old.arrival <= t)
            if done:
                n = new_by[old.order_id]
                assert (n.vehicle_id, n.seq, n.arrival, n.departure, n.status) == \
                       (old.vehicle_id, old.seq, old.arrival, old.departure, "COMPLETED")
        assert check_plan(res.plan, res.vehicles, {o.id: o for o in res.orders}) == []
        assert next(v for v in res.vehicles if v.id == victim).failed


def test_road_closure_forces_resequencing():
    for engine in ENGINES:
        vs = [Vehicle("V01", 500, 5.0)]
        os_ = [Order("O1", "A", 10, 0.1, 480, 600), Order("O2", "B", 10, 0.1, 480, 520)]
        plan = initial_plan(vs, os_, TRI, engine=engine)
        assert [s.order_id for s in plan.route("V01")] == ["O1", "O2"], engine
        inc = Incident(ROAD_CLOSURE, 485, from_location="A", to_location="B")
        res = replan(vs, os_, TRI, plan, inc, engine=engine)
        assert [s.order_id for s in res.plan.route("V01")] == ["O2", "O1"], engine
        assert res.changes["O1"][0] == "MOVED" and res.changes["O2"][0] == "MOVED"
        assert check_plan(res.plan, res.vehicles, {o.id: o for o in res.orders}) == []


def test_urgent_order_inserted():
    for engine in ENGINES:
        vs = [Vehicle("V01", 500, 5.0)]
        os_ = [Order("O1", "A", 10, 0.1, 480, 900)]
        plan = initial_plan(vs, os_, TRI, engine=engine)
        urgent = Order("U1", "B", 20, 0.2, 500, 700, priority=5)
        res = replan(vs, os_, TRI, plan, Incident(URGENT_ORDER, 490, new_order=urgent), engine=engine)
        assert res.plan.by_order()["U1"].vehicle_id == "V01", engine
        assert res.changes["U1"][0] == "MOVED"


def test_urgent_order_too_heavy_is_broken_with_reason():
    for engine in ENGINES:
        vs = [Vehicle("V01", 100, 1.0)]
        os_ = [Order("O1", "A", 10, 0.1, 480, 900)]
        plan = initial_plan(vs, os_, TRI, engine=engine)
        urgent = Order("U1", "B", 900, 0.2, 500, 700)
        res = replan(vs, os_, TRI, plan, Incident(URGENT_ORDER, 490, new_order=urgent), engine=engine)
        status, reason = res.changes["U1"]
        assert status == "BROKEN" and "capacity" in reason.lower(), engine


def test_invalid_incidents_rejected():
    vs, os_, tr = demo_vehicles(), demo_orders(), demo_travel()
    plan = initial_plan(vs, os_, tr, engine="greedy")
    for bad in (Incident(VEHICLE_FAILURE, 690, vehicle_id="V99"),
                Incident(VEHICLE_FAILURE, 690, vehicle_id="V01", location_id="NOWHERE"),
                Incident(ROAD_CLOSURE, 690, from_location="C01", to_location="ZZZ"),
                Incident(VEHICLE_FAILURE, None, vehicle_id="V01")):
        try:
            replan(vs, os_, tr, plan, bad, engine="greedy")
        except IncidentError:
            continue
        raise AssertionError(f"incident should have been rejected: {bad}")
