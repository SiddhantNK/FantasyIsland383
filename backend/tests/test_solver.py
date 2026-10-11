from app.demo_data import demo_orders, demo_travel, demo_vehicles
from app.models import Order, Vehicle
from app.solver import check_plan, initial_plan
from app.travel import apply_closure

try:
    import ortools  # noqa: F401
    ENGINES = ["greedy", "ortools"]
except ImportError:
    ENGINES = ["greedy"]

LINE = {("DEPOT", "A"): 10, ("A", "DEPOT"): 10, ("DEPOT", "B"): 60, ("B", "DEPOT"): 60,
        ("A", "B"): 60, ("B", "A"): 60}


def test_demo_plan_serves_everything_within_constraints():
    for engine in ENGINES:
        vs, os_ = demo_vehicles(), demo_orders()
        plan = initial_plan(vs, os_, demo_travel(), engine=engine)
        assert plan.unassigned() == [], engine
        assert check_plan(plan, vs, {o.id: o for o in os_}) == [], engine


def test_capacity_violation_is_unassigned_with_reason():
    for engine in ENGINES:
        vs = [Vehicle("V1", 100, 1.0)]
        too_heavy = Order("X", "A", 150, 0.5, 480, 900)
        plan = initial_plan(vs, [too_heavy], LINE, engine=engine)
        (s,) = plan.unassigned()
        assert "capacity" in s.reason.lower(), engine


def test_two_orders_one_fits():
    for engine in ENGINES:
        vs = [Vehicle("V1", 100, 1.0)]
        os_ = [Order("X", "A", 60, 0.3, 480, 900), Order("Y", "A", 60, 0.3, 480, 900)]
        plan = initial_plan(vs, os_, LINE, engine=engine)
        assert len(plan.unassigned()) == 1, engine
        assert "No feasible slot" in plan.unassigned()[0].reason, engine


def test_impossible_time_window_reported():
    for engine in ENGINES:
        vs = [Vehicle("V1", 500, 5.0)]
        o = Order("X", "B", 10, 0.1, 480, 500)  # B is 60 min away, latest 08:20
        plan = initial_plan(vs, [o], LINE, engine=engine)
        assert "time window" in plan.unassigned()[0].reason.lower(), engine


def test_waiting_time_is_computed():
    for engine in ENGINES:
        vs = [Vehicle("V1", 500, 5.0)]
        o = Order("X", "A", 10, 0.1, 600, 900)  # arrives 08:10, opens 10:00
        plan = initial_plan(vs, [o], LINE, engine=engine)
        s = plan.route("V1")[0]
        assert (s.arrival, s.wait_min, s.departure) == (490, 110, 610), engine


def test_closure_detour_is_found():
    t = {("A", "B"): 5, ("B", "A"): 5, ("A", "C"): 8, ("C", "A"): 8,
         ("B", "C"): 7, ("C", "B"): 7}
    new = apply_closure(t, "A", "B", 60)
    assert new[("A", "B")] == 15 and new[("B", "A")] == 15  # via C
