"""Travel-time matrix helpers. Matrix = dict[(from_id, to_id)] -> minutes."""
from __future__ import annotations


def tt(travel: dict, a: str, b: str) -> int:
    return 0 if a == b else travel[(a, b)]


def locations_of(travel: dict) -> list:
    return sorted({x for pair in travel for x in pair})


def missing_pairs(travel: dict, locations) -> list:
    return [(a, b) for a in locations for b in locations
            if a != b and (a, b) not in travel]


def shortest_paths(travel: dict) -> dict:
    """Floyd-Warshall closure so detours around a slow edge are visible to the
    optimizer (the solver only ever sees direct entries)."""
    locs = locations_of(travel)
    inf = float("inf")
    d = {(a, b): (0 if a == b else travel.get((a, b), inf))
         for a in locs for b in locs}
    for k in locs:
        for i in locs:
            for j in locs:
                if d[(i, k)] + d[(k, j)] < d[(i, j)]:
                    d[(i, j)] = d[(i, k)] + d[(k, j)]
    return {(a, b): int(v) for (a, b), v in d.items()
            if a != b and v != inf}


def apply_closure(travel: dict, a: str, b: str, extra_min: int) -> dict:
    """Add extra minutes to the a<->b connection (both directions), then
    recompute shortest paths so alternatives are considered."""
    new = dict(travel)
    for pair in ((a, b), (b, a)):
        if pair in new:
            new[pair] += extra_min
    return shortest_paths(new)
