"""ReRoute incident intake: form + Gemini free-text parser -> one validated record in Supabase.

Setup:  pip install supabase google-genai python-dotenv
.env:   SUPABASE_URL, SUPABASE_KEY, GEMINI_API_KEY, (optional) GEMINI_MODEL
"""
import json
import os
import re

from dotenv import load_dotenv
from google import genai
from google.genai import types
from supabase import create_client

load_dotenv()
db = create_client(os.environ["SUPABASE_URL"], os.environ["SUPABASE_KEY"])
llm = genai.Client(api_key=os.environ["GEMINI_API_KEY"])
MODEL = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")

EVENTS = {"VEHICLE_FAILURE", "ROAD_CLOSURE", "URGENT_ORDER"}
REQUIRED = {
    "VEHICLE_FAILURE": ["vehicle_id", "location_id", "incident_time"],
    "ROAD_CLOSURE": ["from_location", "to_location"],
    "URGENT_ORDER": ["location_id", "incident_time", "weight_kg", "volume_m3", "latest"],
}
TIME_FIELDS = ["incident_time", "end_time", "earliest", "latest"]
PROMPT = """Extract a delivery incident from the driver's message. Reply with JSON only:
{"event_type": "VEHICLE_FAILURE|ROAD_CLOSURE|URGENT_ORDER", "vehicle_id": str|null,
 "location_id": str|null, "from_location": str|null, "to_location": str|null,
 "incident_time": "HH:MM"|null, "end_time": "HH:MM"|null,
 "weight_kg": num|null, "volume_m3": num|null, "earliest": "HH:MM"|null,
 "latest": "HH:MM"|null, "notes": str|null}
Rules: 24-hour times. IDs look like V02, C04, L01 (uppercase). Use null for anything not
stated; never guess or invent values. If the message is not an incident, set event_type null.
Message: """


def parse_text(text: str) -> dict:
    """Free-text -> structured dict (unvalidated)."""
    r = llm.models.generate_content(
        model=MODEL,
        contents=PROMPT + text,
        config=types.GenerateContentConfig(
            temperature=0, response_mime_type="application/json"
        ),
    )
    return json.loads(r.text)


def validate(rec: dict) -> dict:
    """Return {'missing': [...], 'errors': [...]}; checks IDs and times against the DB."""
    missing, errors = [], []
    ev = rec.get("event_type")
    if ev not in EVENTS:
        return {"missing": ["event_type"], "errors": ["Unsupported or unclear incident type"]}

    missing = [f for f in REQUIRED[ev] if rec.get(f) in (None, "")]

    vehicles = {v["id"] for v in db.table("vehicles").select("id").execute().data}
    locs = {l["id"] for l in db.table("locations").select("id").execute().data}
    if rec.get("vehicle_id") and rec["vehicle_id"] not in vehicles:
        errors.append(f"Unknown vehicle {rec['vehicle_id']}")
    for f in ("location_id", "from_location", "to_location"):
        if rec.get(f) and rec[f] not in locs:
            errors.append(f"Unknown location {rec[f]}")
    for f in TIME_FIELDS:
        if rec.get(f) and not re.fullmatch(r"([01]\d|2[0-3]):[0-5]\d", rec[f]):
            errors.append(f"Invalid time in {f}: {rec[f]}")

    if ev == "VEHICLE_FAILURE" and rec.get("vehicle_id") in vehicles:
        v = db.table("vehicles").select("status").eq("id", rec["vehicle_id"]).execute().data[0]
        if v["status"] == "FAILED":
            errors.append(f"{rec['vehicle_id']} is already marked failed")

    dup = (
        db.table("disruptions").select("id").eq("event_type", ev)
        .eq("vehicle_id", rec.get("vehicle_id") or "")
        .eq("incident_time", rec.get("incident_time") or "00:00")
        .neq("status", "REJECTED").execute().data
        if rec.get("vehicle_id") else []
    )
    if dup:
        errors.append("Duplicate of an existing incident")
    return {"missing": missing, "errors": errors}


def submit(rec: dict, source: str, raw_text: str | None = None) -> dict:
    """Validate and store. Both form and AI paths end here, so downstream logic is identical.
    Always saved as PENDING (dispatcher confirms); problems go in validation_errors.
    Returns {'saved': bool, 'clarify': [...], 'errors': [...], 'id': int|None}."""
    check = validate(rec)
    if check["missing"]:  # ask the driver instead of inventing details
        return {"saved": False, "clarify": check["missing"], "errors": check["errors"], "id": None}

    ev = rec["event_type"]
    known = db.table("vehicles").select("id").execute().data
    locs = db.table("locations").select("id").execute().data
    ok_v, ok_l = {v["id"] for v in known}, {l["id"] for l in locs}
    pick = lambda k, ok: rec.get(k) if rec.get(k) in ok else None  # FK-safe
    row = {
        "source": source,
        "raw_text": raw_text,
        "event_type": ev,
        "vehicle_id": pick("vehicle_id", ok_v),
        "location_id": pick("location_id", ok_l),
        "from_location": pick("from_location", ok_l),
        "to_location": pick("to_location", ok_l),
        "incident_time": rec.get("incident_time"),
        "end_time": rec.get("end_time"),
        "details": {k: rec.get(k) for k in ("weight_kg", "volume_m3", "earliest", "latest", "notes")
                    if rec.get(k) is not None},
        "validation_errors": check["errors"],
    }
    res = db.table("disruptions").insert(row).execute()
    return {"saved": True, "clarify": [], "errors": check["errors"], "id": res.data[0]["id"]}


def submit_text(text: str) -> dict:
    """Driver free-text path (AI parser)."""
    rec = parse_text(text)
    out = submit(rec, "AI_PARSER", text)
    out["parsed"] = rec  # shown to the driver/dispatcher for correction
    return out


def submit_form(**fields) -> dict:
    """Driver structured-form path (no AI call). Keys match the parser's JSON fields."""
    return submit(fields, "FORM", fields.get("notes"))


if __name__ == "__main__":
    print(submit_text("My truck V02 has broken down near Customer C04 at 11:30 AM. Cannot continue."))
    print(submit_text("My truck broke down"))  # -> asks for vehicle, location, time