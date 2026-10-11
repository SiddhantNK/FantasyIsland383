"""Workflow tests on the in-memory repo (no Supabase / FastAPI needed)."""
from app import service
from app.replan import IncidentError
from app.repo_memory import MemoryRepo

try:
    import ortools  # noqa: F401
    ENGINES = ["greedy", "ortools"]
except ImportError:
    ENGINES = ["greedy"]


def _busiest(plan_json):
    return max(plan_json["vehicles"], key=lambda v: len(v["stops"]))


def _failure(vehicle, time, loc="C01", **kw):
    return dict(event_type="VEHICLE_FAILURE", vehicle_id=vehicle, incident_time=time,
                location_id=loc, **kw)


def test_full_breakdown_flow():
    for engine in ENGINES:
        repo = MemoryRepo()
        p1 = service.create_initial_plan(repo, engine=engine)
        assert p1["feasible"] and p1["version"] == 1
        v = _busiest(p1)
        t = v["stops"][0]["departure"]  # after its first stop
        row = service.submit_incident(repo, _failure(v["id"], t))
        assert row["status"] == "PENDING" and row["validation_errors"] == []
        assert repo.vehicles()[0].failed_at is None  # nothing applied before confirm
        assert repo.latest_plan().version == 1

        out = service.confirm_incident(repo, row["id"], engine=engine)
        p2 = out["plan"]
        assert p2["version"] == 2 and p2["parent_plan_id"] == p1["id"]
        failed = next(x for x in p2["vehicles"] if x["id"] == v["id"])
        assert failed["status"] == "FAILED"
        assert all(s["status"] == "COMPLETED" for s in failed["stops"])
        assert repo.get_disruption(row["id"])["status"] == "CONFIRMED"
        # original plan preserved
        assert repo.get_plan(p1["id"]).version == 1
        cmp = service.compare_with_parent(repo, p2["id"])
        assert sum(cmp["counts"].values()) == 10
        assert len(repo.list_history()) == 1


def test_invalid_incident_is_flagged_and_cannot_be_confirmed():
    repo = MemoryRepo()
    service.create_initial_plan(repo, engine="greedy")
    row = service.submit_incident(repo, _failure("V99", "11:30"))
    assert row["vehicle_id"] is None and row["details"]["unresolved"]["vehicle_id"] == "V99"
    assert any("Unknown vehicle" in e for e in row["validation_errors"])
    try:
        service.confirm_incident(repo, row["id"], engine="greedy")
        raise AssertionError("should not confirm")
    except IncidentError:
        pass
    # dispatcher corrects it, then it confirms
    out = service.confirm_incident(repo, row["id"], {"vehicle_id": "V01"}, engine="greedy")
    assert out["disruption"]["vehicle_id"] == "V01"


def test_reject_and_duplicate_and_unsupported():
    repo = MemoryRepo()
    service.create_initial_plan(repo, engine="greedy")
    a = service.submit_incident(repo, _failure("V01", "11:30"))
    b = service.submit_incident(repo, _failure("V01", "11:31"))
    assert any("Duplicate" in e for e in b["validation_errors"])
    service.reject_incident(repo, a["id"])
    assert repo.get_disruption(a["id"])["status"] == "REJECTED"
    try:
        service.confirm_incident(repo, a["id"], engine="greedy")
        raise AssertionError("rejected incident must not confirm")
    except service.ServiceError as e:
        assert e.status == 409
    try:
        service.submit_incident(repo, {"event_type": "ALIENS"})
        raise AssertionError
    except IncidentError:
        pass


def test_bad_time_is_flagged():
    repo = MemoryRepo()
    row = service.submit_incident(repo, _failure("V01", "eleven thirty"))
    assert any("Invalid time" in e for e in row["validation_errors"])


def test_closure_persists_into_later_replans_then_expires():
    repo = MemoryRepo()
    service.create_initial_plan(repo, engine="greedy")
    c = service.submit_incident(repo, dict(event_type="ROAD_CLOSURE", from_location="C01",
                                           to_location="C02", incident_time="08:30",
                                           end_time="12:00"))
    service.confirm_incident(repo, c["id"], engine="greedy")
    base = repo.travel()[("C01", "C02")]
    assert service.effective_travel(repo, 9 * 60)[("C01", "C02")] >= base   # still in force
    assert service.effective_travel(repo, 13 * 60)[("C01", "C02")] == base  # expired


def test_urgent_order_is_stored_and_assigned():
    repo = MemoryRepo()
    service.create_initial_plan(repo, engine="greedy")
    order = {"id": "U01", "location_id": "C01", "weight_kg": 20, "volume_m3": 0.1,
             "earliest": "09:00", "latest": "17:00"}
    row = service.submit_incident(repo, dict(event_type="URGENT_ORDER", incident_time="09:00",
                                             order=order))
    assert row["validation_errors"] == []
    out = service.confirm_incident(repo, row["id"], engine="greedy")
    assert out["changes"]["U01"]["status"] in ("MOVED", "BROKEN")
    assert "U01" in {o.id for o in repo.orders()}


def test_initial_plan_only_once_and_reset():
    repo = MemoryRepo()
    service.create_initial_plan(repo, engine="greedy")
    try:
        service.create_initial_plan(repo, engine="greedy")
        raise AssertionError
    except service.ServiceError as e:
        assert e.status == 409
    repo.reset()
    assert repo.latest_plan() is None
    service.create_initial_plan(repo, engine="greedy")
