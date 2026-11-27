import hashlib
import json
import sqlite3
import tempfile
import threading
import unittest
from pathlib import Path
from http.client import HTTPConnection
from http.server import ThreadingHTTPServer
from heartbeat_server import Handler

class HistoryHTTPTest(unittest.TestCase):
    def test_ingestion(self):
        with tempfile.TemporaryDirectory() as tmp:
            server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
            server.db_path = str(Path(tmp) / "test.sqlite")
            token = "a" * 40
            server.device_registry = {"pc-a": hashlib.sha256(token.encode()).hexdigest()}
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            payload = {"computer_id": "pc-a", "schema_version": 1,
                       "observed_at_utc": "2026-11-27T19:00:00Z",
                       "probe_status": "ok", "entries": [{
                           "update_id": "12345678-1234-1234-1234-123456789abc",
                           "revision": 1, "recorded_at_utc": "2026-11-27T18:00:00Z",
                           "title": "Test", "result_code": 2, "hresult": "0x00000000"}]}
            def send(key):
                conn = HTTPConnection("127.0.0.1", server.server_port, timeout=5)
                try:
                    conn.request("POST", "/api/v1/update-history", json.dumps(payload),
                                 {"Content-Type": "application/json", "Authorization": "Bearer " + key})
                    response = conn.getresponse()
                    return response.status, json.loads(response.read())
                finally:
                    conn.close()
            try:
                self.assertEqual(send("wrong")[0], 401)
                self.assertEqual(send(token), (200, {"status": "ok", "inserted": 1}))
                self.assertEqual(send(token), (200, {"status": "ok", "inserted": 0}))
                payload["computer_id"] = "pc-b"
                self.assertEqual(send(token)[0], 401)
                payload["computer_id"] = "pc-a"
                payload["entries"][0]["revision"] = -1
                self.assertEqual(send(token)[0], 400)
                with sqlite3.connect(server.db_path) as db:
                    self.assertEqual(db.execute("SELECT count(*) FROM update_history").fetchone()[0], 1)
                server.device_registry = None
                self.assertEqual(send(token)[0], 401)
            finally:
                server.shutdown()
                thread.join()
                server.server_close()

if __name__ == "__main__":
    unittest.main()
