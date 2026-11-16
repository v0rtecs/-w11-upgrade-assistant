import sqlite3
import unittest
from boot_events import init_db, record_heartbeat

NOW = "2026-11-16T12:00:00+00:00"
def msg(at, boot, status="ok"):
    return {"computer_id":"PC-TEST","observed_at_utc":at,"boot_id":boot,"probe_status":status}

class BootEventsTests(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(":memory:")
        init_db(self.db)
    def tearDown(self):
        self.db.close()
    def test_sequence(self):
        a="2026-11-16T08:00:00Z"; b="2026-11-16T11:00:00Z"
        self.assertEqual(record_heartbeat(self.db,msg("2026-11-16T10:00:00Z",a),NOW),"first_seen")
        self.assertEqual(record_heartbeat(self.db,msg("2026-11-16T11:30:00Z",b),NOW),"boot_changed")
        self.assertEqual(record_heartbeat(self.db,msg("2026-11-16T11:30:00Z",b),NOW),"stale")
        self.assertEqual(record_heartbeat(self.db,msg("2026-11-16T10:30:00Z",a),NOW),"stale")
        self.assertEqual(self.db.execute("SELECT COUNT(*) FROM events").fetchone()[0],1)
    def test_probe_error(self):
        record_heartbeat(self.db,msg("2026-11-16T10:00:00Z","2026-11-16T08:00:00Z"),NOW)
        self.assertEqual(record_heartbeat(self.db,msg("2026-11-16T11:00:00Z",None,"error"),NOW),"probe_error")
        self.assertEqual(self.db.execute("SELECT COUNT(*) FROM events").fetchone()[0],0)
if __name__ == "__main__":
    unittest.main()
