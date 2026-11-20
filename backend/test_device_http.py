"""HTTP integration tests for per-device authentication. Python stdlib only."""
import hashlib
import http.client
import json
import os
import sqlite3
import tempfile
import threading
import unittest
from http.server import ThreadingHTTPServer

from boot_events import init_db
from heartbeat_server import Handler


class DeviceHTTPTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.db_path = os.path.join(self.tmp.name, "test.sqlite3")
        with sqlite3.connect(self.db_path) as db:
            init_db(db)
        self.tokens = {"reception-01": "A" * 48, "office-02": "B" * 48}
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.server.db_path = self.db_path
        self.server.device_registry = {
            k: hashlib.sha256(v.encode()).hexdigest() for k, v in self.tokens.items()
        }
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=3)
        self.tmp.cleanup()

    def send(self, device, token, observed="2026-11-20T10:00:00Z",
             boot="2026-11-20T08:00:00Z"):
        conn = http.client.HTTPConnection("127.0.0.1", self.server.server_port, timeout=3)
        body = json.dumps({"computer_id": device, "probe_status": "ok",
                           "boot_id": boot, "observed_at_utc": observed})
        conn.request("POST", "/api/v1/heartbeat", body=body,
                     headers={"Authorization": "Bearer " + token,
                              "Content-Type": "application/json"})
        response = conn.getresponse()
        status = response.status
        data = json.loads(response.read())
        conn.close()
        return status, data

    def test_each_device_authenticates_independently(self):
        self.assertEqual(self.send("reception-01", self.tokens["reception-01"])[0], 200)
        self.assertEqual(self.send("office-02", self.tokens["office-02"])[0], 200)

    def test_cross_device_impersonation_is_rejected(self):
        self.assertEqual(self.send("office-02", self.tokens["reception-01"])[0], 401)
        self.assertEqual(self.send("reception-01", self.tokens["office-02"])[0], 401)
        self.assertEqual(self.send("unknown-03", self.tokens["reception-01"])[0], 401)

    def test_revocation_affects_only_one_device(self):
        del self.server.device_registry["reception-01"]
        self.assertEqual(self.send("reception-01", self.tokens["reception-01"])[0], 401)
        self.assertEqual(self.send("office-02", self.tokens["office-02"])[0], 200)

    def test_rejected_message_does_not_change_database(self):
        self.assertEqual(self.send("office-02", self.tokens["reception-01"])[0], 401)
        with sqlite3.connect(self.db_path) as db:
            self.assertEqual(db.execute("SELECT COUNT(*) FROM devices").fetchone()[0], 0)


if __name__ == "__main__":
    unittest.main()
