"""Read-only dashboard snapshot. Python 3.9+, standard library only.

This module does not expose an HTTP endpoint or credentials. All timestamps UTC.
"""
import datetime as dt
import sqlite3
from boot_events import parse_utc

def snapshot(db: sqlite3.Connection, now=None, stale_after_seconds=180):
    """Return a compact overview. Offline means no recent heartbeat, not proof of power-off."""
    if not 1 <= stale_after_seconds <= 86400:
        raise ValueError("stale_after_seconds must be 1..86400")
    current = parse_utc(now or dt.datetime.now(dt.timezone.utc).isoformat())
    rows = db.execute("""SELECT d.computer_id, d.boot_id, d.last_seen_utc,
        (SELECT MAX(e.received_at_utc) FROM events e
         WHERE e.computer_id=d.computer_id AND e.event_type='BOOT_CHANGED')
        FROM devices d ORDER BY d.computer_id""").fetchall()
    devices = []
    for cid, boot, seen, last_reboot in rows:
        age = max(0, int((current - parse_utc(seen)).total_seconds()))
        devices.append({
            "computer_id": cid,
            "status": "online" if age <= stale_after_seconds else "no_recent_contact",
            "last_seen_utc": seen,
            "seconds_since_observation": age,
            "boot_id": boot,
            "last_reboot_detected_utc": last_reboot,
        })
    return {
        "generated_at_utc": current.isoformat(),
        "stale_after_seconds": stale_after_seconds,
        "total": len(devices),
        "online": sum(d["status"] == "online" for d in devices),
        "no_recent_contact": sum(d["status"] == "no_recent_contact" for d in devices),
        "devices": devices,
    }
