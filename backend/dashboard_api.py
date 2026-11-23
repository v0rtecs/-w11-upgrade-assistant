"""Read-only dashboard API, loopback only. Python 3.9+ standard library.
Never expose directly to LAN/Internet. Use HTTPS reverse proxy and separate
operator authentication for any remote/mobile access.
"""
import hmac
import json
import os
import sqlite3
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from dashboard_snapshot import snapshot

class DashboardHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/api/v1/dashboard":
            return self.respond(404, {"error": "not_found"})
        supplied = self.headers.get("Authorization", "")
        expected = "Bearer " + self.server.dashboard_token
        if not hmac.compare_digest(supplied, expected):
            return self.respond(401, {"error": "unauthorized"})
        try:
            with sqlite3.connect("file:" + self.server.db_path + "?mode=ro", uri=True, timeout=5) as db:
                data = snapshot(db)
        except (sqlite3.Error, ValueError):
            return self.respond(503, {"error": "snapshot_unavailable"})
        return self.respond(200, data)

    def do_POST(self):
        return self.respond(405, {"error": "method_not_allowed"})

    def respond(self, status, data):
        body = json.dumps(data, separators=(",", ":")).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        pass

def serve():
    token = os.environ.get("W11_DASHBOARD_TOKEN", "")
    if len(token) < 32:
        raise SystemExit("Set W11_DASHBOARD_TOKEN to a random 32+ character secret")
    db_path = os.path.abspath(os.environ.get("W11_DB_PATH", "w11-heartbeats.sqlite3"))
    if not os.path.isfile(db_path):
        raise SystemExit("Database does not exist; start heartbeat receiver first")
    server = ThreadingHTTPServer(("127.0.0.1", int(os.environ.get("W11_DASHBOARD_PORT", "8766"))), DashboardHandler)
    server.dashboard_token = token
    server.db_path = db_path
    print("Dashboard API listening on loopback only; do not expose directly")
    server.serve_forever()

if __name__ == "__main__":
    serve()
