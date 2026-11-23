"""Integration tests: python -m unittest test_dashboard_api.py (from backend/)."""
import datetime as dt
import http.client
import json
import os
import sqlite3
import tempfile
import threading
import unittest
from http.server import ThreadingHTTPServer
from boot_events import init_db, record_heartbeat
from dashboard_api import DashboardHandler

class DashboardAPITests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.db_path = os.path.join(self.tmp.name, "test.sqlite3")
        with sqlite3.connect(self.db_path) as db:
            init_db(db)
            now = dt.datetime.now(dt.timezone.utc)
            record_heartbeat(db, {
                "computer_id": "test-pc", "probe_status": "ok",
                "boot_id": (now - dt.timedelta(hours=1)).isoformat(),
                "observed_at_utc": now.isoformat()
            })
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), DashboardHandler)
        self.server.dashboard_token = "T" * 40
        self.server.db_path = self.db_path
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=3)
        self.tmp.cleanup()

    def request(self, method, path, token=None):
        conn = http.client.HTTPConnection("127.0.0.1", self.server.server_port, timeout=3)
        headers = {"Authorization": "Bearer " + token} if token else {}
        conn.request(method, path, headers=headers)
        response = conn.getresponse()
        status, headers, body = response.status, response.headers, response.read()
        conn.close()
        return status, headers, json.loads(body)

    def test_requires_operator_token(self):
        self.assertEqual(self.request("GET", "/api/v1/dashboard")[0], 401)
        self.assertEqual(self.request("GET", "/api/v1/dashboard", "wrong")[0], 401)

    def test_snapshot_and_cache_policy(self):
        status, headers, body = self.request("GET", "/api/v1/dashboard", "T" * 40)
        self.assertEqual(status, 200)
        self.assertEqual(headers["Cache-Control"], "no-store")
        self.assertEqual(body["total"], 1)
        self.assertEqual(body["devices"][0]["computer_id"], "test-pc")

    def test_read_only_and_unknown_route(self):
        self.assertEqual(self.request("POST", "/api/v1/dashboard", "T" * 40)[0], 405)
        self.assertEqual(self.request("GET", "/other", "T" * 40)[0], 404)

if __name__ == "__main__":
    unittest.main()
