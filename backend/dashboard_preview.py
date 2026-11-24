"""Local dashboard preview; reuses the existing authenticated API."""
from pathlib import Path
import dashboard_api

class PreviewHandler(dashboard_api.DashboardHandler):
    def do_GET(self):
        if self.path != "/":
            return super().do_GET()
        body = (Path(__file__).resolve().parent.parent / "dashboard" / "index.html").read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Content-Security-Policy", "default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'self'; form-action 'none'; frame-ancestors 'none'; base-uri 'none'")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

if __name__ == "__main__":
    dashboard_api.DashboardHandler = PreviewHandler
    dashboard_api.serve()
