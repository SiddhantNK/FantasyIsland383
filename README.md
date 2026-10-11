# VORTEXA 3.0 Hackathon
## Team FantasyIsland383

This is the official github repository of the project built for the hackathon
# ReRoute

The Flutter app is in `reroute_app/`. See [`reroute_app/README.md`](reroute_app/README.md) for Supabase email/password authentication setup and run instructions.

# ReRoute backend

## Setup
    python -m venv .venv && source .venv/bin/activate     # Windows: .venv\Scripts\activate
    pip install -r requirements.txt
    pytest -q

## Supabase (once)
1. Run the team's original schema, then `db/migration_001.sql`.
2. Run `db/seed.sql` (or load your own data; `python -m app.seed_sql` regenerates it).
3. `cp .env.example .env` and fill in SUPABASE_URL / SUPABASE_KEY (service_role).

## Run
    uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
    # no Supabase yet?  REROUTE_REPO=memory uvicorn app.main:app --reload
Interactive docs: http://localhost:8000/docs

## Endpoints
GET /health, /state | POST /plans/initial | GET /plans, /plans/latest, /plans/{id}, /plans/{id}/compare
POST /incidents (form + AI parser, `source`) | POST /incidents/parse (501 until parser connected)
GET /incidents?status=PENDING | PATCH /incidents/{id} | POST /incidents/{id}/confirm | /reject
GET /history | POST /admin/reset (demo re-runs)

## Conventions
Times are "HH:MM" in JSON. Stops with vehicle_id=null are unassigned (BROKEN + reason).
Completed stop = service finished by the incident time (healthy vehicles: also if
already at the stop). Replanning never schedules before the incident time. A closure
adds (end_time - now) minutes to the road both ways (60 if no end time), then shortest
paths are recomputed; confirmed closures are re-applied on later replans until they expire.
