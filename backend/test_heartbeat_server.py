"""Integration tests for the loopback heartbeat HTTP receiver (stdlib only)."""
import http.client
import json
import os
import sqlite3
import tempfile
import threading
import unittest
from http.server import ThreadingHTTPServer
from unittest.mock import patch

from boot_events import init_db
from heartbeat_server import Handler


class HeartbeatHTTPTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.db_path = os.path.join(self.tmp.name, "heartbeats.sqlite3")
        with sqlite3.connect(self.db_path) as db:
            init_db(db)
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.server.db_path = self.db_path
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.token = "test-token-" + "x" * 40
        self.env = patch.dict(os.environ, {"W11_AGENT_TOKEN": self.token})
        self.env.start()

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=3)
        self.env.stop()
        self.tmp.cleanup()

    def request(self, body, token=None, content_type="application/json", path="/api/v1/heartbeat"):
        conn = http.client.HTTPConnection("127.0.0.1", self.server.server_port, timeout=3)
        headers = {"Content-Type": content_type}
        if token is not None:
            headers["Authorization"] = "Bearer " + token
        conn.request("POST", path, body=body, headers=headers)
        response = conn.getresponse()
        status = response.status
        data = json.loads(response.read())
        conn.close()
        return status, data

    def payload(self, boot="2026-11-18T08:00:00Z", observed="2026-11-18T09:00:00Z"):
        return json.dumps({"computer_id": "reception-01", "probe_status": "ok",
                           "boot_id": boot, "observed_at_utc": observed}).encode()

    def test_auth_and_validation(self):
        self.assertEqual(self.request(self.payload())[0], 401)
        self.assertEqual(self.request(self.payload(), "wrong")[0], 401)
        self.assertEqual(self.request(self.payload(), self.token, path="/wrong")[0], 404)
        self.assertEqual(self.request(self.payload(), self.token, "text/plain")[0], 415)
        self.assertEqual(self.request(b"{", self.token)[0], 400)
        self.assertEqual(self.request(b"x" * 4097, self.token)[0], 413)

    def test_boot_transition_and_duplicate(self):
        self.assertEqual(self.request(self.payload(), self.token), (200, {"status": "first_seen"}))
        self.assertEqual(self.request(self.payload(), self.token), (200, {"status": "stale"}))
        changed = self.payload("2026-11-18T09:05:00Z", "2026-11-18T09:10:00Z")
        self.assertEqual(self.request(changed, self.token), (200, {"status": "boot_changed"}))
        with sqlite3.connect(self.db_path) as db:
            events = db.execute("SELECT event_type FROM events").fetchall()
        self.assertEqual(events, [("BOOT_CHANGED",)])

    def test_probe_error_does_not_create_reboot(self):
        self.request(self.payload(), self.token)
        error = json.dumps({"computer_id": "reception-01", "probe_status": "error",
                            "observed_at_utc": "2026-11-18T09:10:00Z"}).encode()
        self.assertEqual(self.request(error, self.token), (200, {"status": "probe_error"}))
        with sqlite3.connect(self.db_path) as db:
            self.assertEqual(db.execute("SELECT COUNT(*) FROM events").fetchone()[0], 0)


if __name__ == "__main__":
    unittest.main()
