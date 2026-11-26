"""Validated, idempotent storage for Windows Update history batches."""
import sqlite3
from datetime import datetime, timezone
from uuid import UUID
import re

def utc(value):
    if not isinstance(value, str) or len(value) > 40:
        raise ValueError("invalid timestamp")
    d = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if d.tzinfo is None:
        raise ValueError("timezone required")
    return d.astimezone(timezone.utc).isoformat()

def init_db(db):
    db.execute("""CREATE TABLE IF NOT EXISTS update_history (
        computer_id TEXT NOT NULL, update_id TEXT NOT NULL,
        revision INTEGER NOT NULL, recorded_at TEXT NOT NULL,
        title TEXT NOT NULL, result_code INTEGER NOT NULL, hresult TEXT NOT NULL,
        PRIMARY KEY(computer_id, update_id, revision, recorded_at, result_code, hresult)
    )""")
    db.execute("""CREATE TABLE IF NOT EXISTS update_probe (
        computer_id TEXT PRIMARY KEY, observed_at TEXT NOT NULL, status TEXT NOT NULL
    )""")

def record_batch(db, computer_id, payload):
    if not isinstance(computer_id, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,127}", computer_id):
        raise ValueError("invalid computer")
    if not isinstance(payload, dict) or payload.get("schema_version") != 1:
        raise ValueError("invalid schema")
    observed = utc(payload["observed_at_utc"])
    status = payload["probe_status"]
    entries = payload["entries"]
    if status not in ("ok", "error") or not isinstance(entries, list) or len(entries) > 100 or (status == "error" and entries):
        raise ValueError("invalid batch")
    rows = []
    for e in entries:
        if not isinstance(e, dict):
            raise ValueError("invalid entry")
        uid = str(UUID(e["update_id"]))
        rev, result = e["revision"], e["result_code"]
        title, hr = e["title"], e["hresult"]
        if type(rev) is not int or not 0 <= rev <= 2147483647 or type(result) is not int or not 0 <= result <= 2147483647:
            raise ValueError("invalid codes")
        if not isinstance(title, str) or len(title) > 2048 or not isinstance(hr, str) or not re.fullmatch(r"0x[0-9a-fA-F]{8}", hr):
            raise ValueError("invalid text")
        rows.append((computer_id, uid, rev, utc(e["recorded_at_utc"]), title, result, hr.upper()))
    with db:
        before = db.total_changes
        db.executemany("INSERT OR IGNORE INTO update_history VALUES (?,?,?,?,?,?,?)", rows)
        inserted = db.total_changes - before
        db.execute("""INSERT INTO update_probe VALUES (?,?,?)
            ON CONFLICT(computer_id) DO UPDATE SET observed_at=excluded.observed_at,status=excluded.status
            WHERE excluded.observed_at > update_probe.observed_at""", (computer_id, observed, status))
    return inserted
