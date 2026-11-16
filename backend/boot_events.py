"""Idempotent heartbeat/boot-change recorder. Python 3.9+, standard library only.
This is a storage component, NOT a network endpoint. Authenticate HTTPS requests upstream.
"""
import datetime as dt
import sqlite3

def parse_utc(value):
    if not isinstance(value, str):
        raise ValueError("timestamp must be a string")
    parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        raise ValueError("timestamp must include timezone")
    return parsed.astimezone(dt.timezone.utc)

def init_db(db):
    db.execute("""CREATE TABLE IF NOT EXISTS devices (
        computer_id TEXT PRIMARY KEY, boot_id TEXT, last_seen_utc TEXT NOT NULL
    )""")
    db.execute("""CREATE TABLE IF NOT EXISTS events (
        id INTEGER PRIMARY KEY AUTOINCREMENT, computer_id TEXT NOT NULL,
        event_type TEXT NOT NULL, previous_boot_id TEXT, boot_id TEXT NOT NULL,
        received_at_utc TEXT NOT NULL,
        UNIQUE(computer_id, event_type, boot_id)
    )""")

def record_heartbeat(db, payload, received_at=None):
    """Returns first_seen, unchanged, boot_changed, stale, or probe_error.
    Caller must serialize writes per SQLite database (BEGIN IMMEDIATE).
    """
    cid = payload.get("computer_id")
    if not isinstance(cid, str) or not (1 <= len(cid) <= 128):
        raise ValueError("invalid computer_id")
    now = parse_utc(received_at or dt.datetime.now(dt.timezone.utc).isoformat())
    observed = parse_utc(payload["observed_at_utc"])
    if observed > now + dt.timedelta(minutes=5):
        raise ValueError("observation too far in future")
    status = payload.get("probe_status")
    boot = payload.get("boot_id")
    if status == "ok":
        boot_dt = parse_utc(boot)
        if boot_dt > observed + dt.timedelta(minutes=2):
            raise ValueError("boot later than observation")
        boot = boot_dt.isoformat()
    elif status == "error":
        boot = None
    else:
        raise ValueError("invalid probe_status")
    with db:
        db.execute("BEGIN IMMEDIATE") if not db.in_transaction else None
        old = db.execute("SELECT boot_id,last_seen_utc FROM devices WHERE computer_id=?", (cid,)).fetchone()
        if old and observed <= parse_utc(old[1]):
            return "stale"
        if not old:
            db.execute("INSERT INTO devices VALUES (?,?,?)", (cid, boot, observed.isoformat()))
            return "first_seen" if boot else "probe_error"
        previous = old[0]
        effective = boot or previous
        db.execute("UPDATE devices SET boot_id=?,last_seen_utc=? WHERE computer_id=?",
                   (effective, observed.isoformat(), cid))
        if boot is None:
            return "probe_error"
        if previous and previous != boot:
            db.execute("""INSERT OR IGNORE INTO events
                (computer_id,event_type,previous_boot_id,boot_id,received_at_utc)
                VALUES (?,?,?,?,?)""", (cid, "BOOT_CHANGED", previous, boot, now.isoformat()))
            return "boot_changed"
        return "unchanged"
