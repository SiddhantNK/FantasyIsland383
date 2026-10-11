"""Initial route generation + scheduling + unassigned-order explanations.

engine="ortools" is the real optimizer. engine="greedy" is a small
cheapest-insertion heuristic used for quick dev/testing without OR-Tools.
"""
from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Optional

from .models import DEPOT, Order, Plan, Stop, Vehicle, hhmm
from .travel import tt

HORIZON = 2880          # minutes the time dimension may span
BASE_PENALTY = 1_000_000  # cost of dropping a priority-1 order
PRIORITY_LABELS = {1: "Standard", 2: "High", 3: "Critical"}


@dataclass
class VehicleState:
    """Where/when a vehicle is available to start (re)planning."""
    vehicle: Vehicle
    start_loc: str = DEPOT
    start_time: int = 480
    seq_start: int = 1  # first seq number to assign to new stops


# ---------------------------------------------------------------- scheduling
def compute_schedule(start_loc, start_time, seq, travel, not_before=0):
    """Deterministic schedule for an ordered list of Orders.

    Returns ([(arrival, wait, departure), ...], feasible). `arrival` is the
    physical arrival; service begins at max(arrival, earliest, not_before).
    Feasible = every service begins no later than the order's `latest`.
    """
    t, loc, out, ok = start_time, start_loc, [], True
    for o in seq:
        arr = t + tt(travel, loc, o.location_id)
        begin = max(arr, o.earliest, not_before)
        if begin > o.latest:
            ok = False
        out.append((arr, begin - arr, begin + o.service_min))
        t, loc = begin + o.service_min, o.location_id
    return out, ok


def _fits(vehicle: Vehicle, seq) -> bool:
    return (sum(o.weight for o in seq) <= vehicle.weight_cap + 1e-9
            and sum(o.volume for o in seq) <= vehicle.volume_cap + 1e-9)


# ------------------------------------------------------------- explanations
def explain_unassigned(order: Order, states, travel, not_before=0) -> str:
    plabel = PRIORITY_LABELS.get(order.priority, f"P{order.priority}")
    prefix = f"[{plabel} priority] " if order.priority > 1 else ""
    if not states:
        return f"{prefix}No available vehicle: all vehicles have failed or none exist."
    lo = max(order.earliest, not_before)
    if lo > order.latest:
        return (f"{prefix}Time window closed: latest delivery {hhmm(order.latest)} is "
                f"before the earliest feasible service time {hhmm(lo)}.")
    capable = [s for s in states
               if order.weight <= s.vehicle.weight_cap + 1e-9
               and order.volume <= s.vehicle.volume_cap + 1e-9]
    if not capable:
        mw = max(s.vehicle.weight_cap for s in states)
        mv = max(s.vehicle.volume_cap for s in states)
        return (f"{prefix}Insufficient vehicle capacity: order needs {order.weight:g} kg / "
                f"{order.volume:g} m3, largest available vehicle holds "
                f"{mw:g} kg / {mv:g} m3.")
    earliest = min(max(s.start_time + tt(travel, s.start_loc, order.location_id), lo)
                   for s in capable)
    if earliest > order.latest:
        return (f"{prefix}Time window infeasible: earliest possible arrival "
                f"{hhmm(earliest)} is after the latest allowed {hhmm(order.latest)}.")
    return (f"{prefix}No feasible slot: remaining capacity and the time windows of other "
            "assigned orders leave no room for this order.")


# ------------------------------------------------------------------- engines
def _up(x):   # conservative scaling for demands
    return int(math.ceil(x * 100 - 1e-9))


def _down(x):  # conservative scaling for capacities
    return int(math.floor(x * 100 + 1e-9))


def _route_ortools(states, orders, travel, not_before, time_limit_s):
    from ortools.constraint_solver import pywrapcp, routing_enums_pb2

    n, V = len(orders), len(states)
    END = n + V
    num_nodes = n + V + 1
    loc = [o.location_id for o in orders] + [s.start_loc for s in states] + [None]
    service = [o.service_min for o in orders] + [0] * (V + 1)

    def tmin(a, b):
        if loc[a] is None or loc[b] is None:
            return 0  # routes are open: no cost to "end"
        return tt(travel, loc[a], loc[b])

    tmat = [[tmin(a, b) for b in range(num_nodes)] for a in range(num_nodes)]

    manager = pywrapcp.RoutingIndexManager(
        num_nodes, V, [n + v for v in range(V)], [END] * V)
    routing = pywrapcp.RoutingModel(manager)

    def travel_cb(i, j):
        return tmat[manager.IndexToNode(i)][manager.IndexToNode(j)]

    def time_cb(i, j):
        a = manager.IndexToNode(i)
        return tmat[a][manager.IndexToNode(j)] + service[a]

    routing.SetArcCostEvaluatorOfAllVehicles(routing.RegisterTransitCallback(travel_cb))
    routing.AddDimension(routing.RegisterTransitCallback(time_cb),
                         HORIZON, HORIZON, False, "Time")
    time_dim = routing.GetDimensionOrDie("Time")

    for i, o in enumerate(orders):
        lo, hi = max(o.earliest, not_before), min(o.latest, HORIZON)
        time_dim.CumulVar(manager.NodeToIndex(i)).SetRange(lo, hi)
    for v, s in enumerate(states):
        time_dim.CumulVar(routing.Start(v)).SetRange(s.start_time, s.start_time)

    def dem(values):
        return routing.RegisterUnaryTransitCallback(
            lambda i: values[manager.IndexToNode(i)])

    w = [_up(o.weight) for o in orders] + [0] * (V + 1)
    vol = [_up(o.volume) for o in orders] + [0] * (V + 1)
    routing.AddDimensionWithVehicleCapacity(
        dem(w), 0, [_down(s.vehicle.weight_cap) for s in states], True, "Weight")
    routing.AddDimensionWithVehicleCapacity(
        dem(vol), 0, [_down(s.vehicle.volume_cap) for s in states], True, "Volume")

    for i, o in enumerate(orders):  # orders may be dropped, at a price
        # Quadratic scaling: P1=1M, P2=4M, P3=9M — makes dropping high-priority orders
        # very expensive relative to standard ones
        routing.AddDisjunction([manager.NodeToIndex(i)],
                               BASE_PENALTY * max(1, o.priority) ** 2)

    params = pywrapcp.DefaultRoutingSearchParameters()
    params.first_solution_strategy = routing_enums_pb2.FirstSolutionStrategy.PATH_CHEAPEST_ARC
    params.local_search_metaheuristic = routing_enums_pb2.LocalSearchMetaheuristic.GUIDED_LOCAL_SEARCH
    params.time_limit.FromSeconds(time_limit_s)
    solution = routing.SolveWithParameters(params)

    routes = {s.vehicle.id: [] for s in states}
    if solution is None:
        return routes
    for v, s in enumerate(states):
        idx = routing.Start(v)
        while not routing.IsEnd(idx):
            node = manager.IndexToNode(idx)
            if node < n:
                routes[s.vehicle.id].append(orders[node])
            idx = solution.Value(routing.NextVar(idx))
    return routes


def _route_greedy(states, orders, travel, not_before, time_limit_s=None):
    routes = {s.vehicle.id: [] for s in states}
    for o in sorted(orders, key=lambda o: (-o.priority, o.latest, o.id)):
        best = None
        for s in states:
            cur = routes[s.vehicle.id]
            if not _fits(s.vehicle, cur + [o]):
                continue
            prev_sched, _ = compute_schedule(s.start_loc, s.start_time, cur, travel, not_before)
            prev_end = prev_sched[-1][2] if prev_sched else s.start_time
            for pos in range(len(cur) + 1):
                cand = cur[:pos] + [o] + cur[pos:]
                sched, ok = compute_schedule(s.start_loc, s.start_time, cand, travel, not_before)
                if not ok:
                    continue
                key = (sched[-1][2] - prev_end, s.vehicle.id)
                if best is None or key < best[0]:
                    best = (key, s.vehicle.id, cand)
        if best:
            routes[best[1]] = best[2]
    return routes


# --------------------------------------------------------------------- solve
def solve(states, orders, travel, not_before=0, time_limit_s=2, engine="ortools") -> Plan:
    """Assign `orders` to vehicles (`states`) and sequence them.

    Orders that cannot be served come back as Stop(vehicle_id=None,
    status='BROKEN', reason=...) in the returned Plan.
    """
    reasons, candidates = {}, []
    for o in orders:
        if max(o.earliest, not_before) > o.latest:
            reasons[o.id] = explain_unassigned(o, states, travel, not_before)
        else:
            candidates.append(o)

    routes = {s.vehicle.id: [] for s in states}
    if states and candidates:
        run = _route_ortools if engine == "ortools" else _route_greedy
        routes = run(states, candidates, travel, not_before, time_limit_s)

    stops = []
    for s in states:
        seq = routes.get(s.vehicle.id, [])
        sched, _ = compute_schedule(s.start_loc, s.start_time, seq, travel, not_before)
        for i, (o, (arr, wait, dep)) in enumerate(zip(seq, sched)):
            stops.append(Stop(s.vehicle.id, o.id, s.seq_start + i, o.location_id,
                              arr, wait, dep, "PLANNED"))
    placed = {st.order_id for st in stops}
    for o in orders:
        if o.id not in placed:
            reason = reasons.get(o.id) or explain_unassigned(o, states, travel, not_before)
            stops.append(Stop(None, o.id, 0, o.location_id, None, 0, None, "BROKEN", reason))
    return Plan(stops=stops)


def initial_plan(vehicles, orders, travel, depot=DEPOT, shift_start=480,
                 time_limit_s=2, engine="ortools") -> Plan:
    states = [VehicleState(v, depot, shift_start) for v in vehicles if not v.failed]
    return solve(states, orders, travel, 0, time_limit_s, engine)


def check_plan(plan: Plan, vehicles, orders_by_id) -> list:
    """Independent verification of mandatory constraints. [] means valid."""
    problems = []
    for v in vehicles:
        pending = [orders_by_id[s.order_id] for s in plan.route(v.id)
                   if s.status != "COMPLETED"]
        if sum(o.weight for o in pending) > v.weight_cap + 1e-9:
            problems.append(f"{v.id}: weight capacity exceeded")
        if sum(o.volume for o in pending) > v.volume_cap + 1e-9:
            problems.append(f"{v.id}: volume capacity exceeded")
    for s in plan.stops:
        if s.vehicle_id is None:
            continue
        o = orders_by_id[s.order_id]
        begin = s.arrival + s.wait_min
        if begin > o.latest:
            problems.append(f"{o.id}: service starts {hhmm(begin)} after latest {hhmm(o.latest)}")
        if begin < o.earliest:
            problems.append(f"{o.id}: service starts {hhmm(begin)} before earliest {hhmm(o.earliest)}")
    return problems
