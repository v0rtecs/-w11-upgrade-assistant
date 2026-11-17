"""Minimal authenticated heartbeat receiver. Python 3.9+, stdlib only.
Loopback HTTP ONLY: place behind an HTTPS reverse proxy with access controls.
Never expose this HTTP service directly to the LAN or Internet.
"""
import hmac
import json
import os
import sqlite3
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from boot_events import init_db, record_heartbeat

MAX_BODY = 4096

class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path != "/api/v1/heartbeat":
            return self.reply(404, {"error": "not_found"})
        token = os.environ.get("W11_AGENT_TOKEN", "")
        supplied = self.headers.get("Authorization", "")
        if not token or not hmac.compare_digest(supplied, "Bearer " + token):
            return self.reply(401, {"error": "unauthorized"})
        try:
            length = int(self.headers.get("Content-Length", "-1"))
        except ValueError:
            length = -1
        if not 0 < length <= MAX_BODY:
            return self.reply(413, {"error": "invalid_size"})
        if self.headers.get("Content-Type", "").split(";")[0].strip().lower() != "application/json":
            return self.reply(415, {"error": "json_required"})
        try:
            payload = json.loads(self.rfile.read(length))
            if not isinstance(payload, dict):
                raise ValueError("object required")
            with sqlite3.connect(self.server.db_path, timeout=10) as db:
                db.execute("PRAGMA busy_timeout=10000")
                result = record_heartbeat(db, payload)
        except (ValueError, KeyError, TypeError, json.JSONDecodeError):
            return self.reply(400, {"error": "invalid_payload"})
        except sqlite3.Error:
            return self.reply(503, {"error": "storage_unavailable"})
        return self.reply(200, {"status": result})

    def do_GET(self):
        return self.reply(404, {"error": "not_found"})

    def reply(self, code, payload):
        body = json.dumps(payload, separators=(",", ":")).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        # Avoid accidentally logging Authorization headers or payloads.
        pass

def serve():
    token = os.environ.get("W11_AGENT_TOKEN", "")
    if len(token) < 32:
        raise SystemExit("Set W11_AGENT_TOKEN to a random secret of at least 32 characters")
    db_path = os.environ.get("W11_DB_PATH", "w11-heartbeats.sqlite3")
    with sqlite3.connect(db_path) as db:
        init_db(db)
    server = ThreadingHTTPServer(("127.0.0.1", int(os.environ.get("W11_PORT", "8765"))), Handler)
    server.db_path = db_path
    print("Heartbeat receiver listening on loopback only; HTTPS proxy required for remote access")
    server.serve_forever()

if __name__ == "__main__":
    serve()
