import sqlite3
import unittest
from update_history_store import init_db, record_batch

class HistoryTests(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(":memory:")
        self.addCleanup(self.db.close)
        init_db(self.db)
        self.batch = dict(schema_version=1, probe_status="ok", observed_at_utc="2026-11-26T19:00:00Z", entries=[dict(update_id="12345678-1234-1234-1234-123456789abc", revision=1, recorded_at_utc="2026-11-26T18:00:00Z", title="Test", result_code=2, hresult="0x00000000")])
    def test_duplicate_and_device_isolation(self):
        self.assertEqual(record_batch(self.db,"PC-A",self.batch),1)
        self.assertEqual(record_batch(self.db,"PC-A",self.batch),0)
        self.assertEqual(record_batch(self.db,"PC-B",self.batch),1)
    def test_invalid_batch_atomic(self):
        self.batch["entries"].append({})
        with self.assertRaises((ValueError, KeyError)):
            record_batch(self.db,"PC-A",self.batch)
        self.assertEqual(self.db.execute("SELECT count(*) FROM update_history").fetchone()[0],0)
    def test_error_preserves_history(self):
        record_batch(self.db,"PC-A",self.batch)
        record_batch(self.db,"PC-A",dict(self.batch,probe_status="error",entries=[],observed_at_utc="2026-11-26T20:00:00Z"))
        self.assertEqual(self.db.execute("SELECT count(*) FROM update_history").fetchone()[0],1)
        self.assertEqual(self.db.execute("SELECT status FROM update_probe").fetchone()[0],"error")
    def test_old_probe_does_not_replace_new(self):
        record_batch(self.db,"PC-A",self.batch)
        record_batch(self.db,"PC-A",dict(self.batch,probe_status="error",entries=[],observed_at_utc="2026-11-26T17:00:00Z"))
        self.assertEqual(self.db.execute("SELECT status FROM update_probe").fetchone()[0],"ok")

if __name__ == "__main__":
    unittest.main()
