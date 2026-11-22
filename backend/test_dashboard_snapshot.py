"""Offline tests for dashboard snapshot: python -m unittest test_dashboard_snapshot.py"""
import datetime as dt
import sqlite3
import unittest
from boot_events import init_db, record_heartbeat
from dashboard_snapshot import snapshot

class SnapshotTests(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(":memory:")
        init_db(self.db)
        self.now = "2026-11-22T12:00:00+00:00"

    def tearDown(self):
        self.db.close()

    def add(self, cid, observed, boot="2026-11-22T08:00:00Z"):
        return record_heartbeat(self.db, {
            "computer_id": cid, "probe_status": "ok",
            "observed_at_utc": observed, "boot_id": boot,
        }, received_at=self.now)

    def test_empty(self):
        result = snapshot(self.db, self.now)
        self.assertEqual((result["total"], result["online"]), (0, 0))

    def test_online_boundary_and_missing(self):
        self.add("a", "2026-11-22T11:57:00Z")
        self.add("b", "2026-11-22T11:56:59Z")
        result = snapshot(self.db, self.now, 180)
        self.assertEqual((result["online"], result["no_recent_contact"]), (1, 1))
        self.assertEqual([d["status"] for d in result["devices"]],
                         ["online", "no_recent_contact"])

    def test_reboot_event_and_no_false_duration(self):
        self.add("a", "2026-11-22T11:50:00Z")
        self.add("a", "2026-11-22T11:59:00Z", "2026-11-22T11:55:00Z")
        result = snapshot(self.db, self.now)
        self.assertIsNotNone(result["devices"][0]["last_reboot_detected_utc"])
        self.assertNotIn("reboot_duration_seconds", result["devices"][0])

    def test_bad_threshold(self):
        with self.assertRaises(ValueError):
            snapshot(self.db, self.now, 0)

if __name__ == "__main__":
    unittest.main()
