import os
import json
from http.server import BaseHTTPRequestHandler, HTTPServer

def get_trusted_edge_token():
    token = os.environ.get("CN_EDGE_SECRET")
    if token:
        return token
    # Load from secure config/.secrets.env if present
    secrets_path = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "config", ".secrets.env")
    if os.path.exists(secrets_path):
        try:
            with open(secrets_path) as f:
                for line in f:
                    line = line.strip()
                    if line.startswith("CN_EDGE_SECRET="):
                        return line.split("=", 1)[1].strip('"\'')
        except Exception:
            pass
    return None

class Handler(BaseHTTPRequestHandler):

    def is_authorized(self):
        isolation_enabled = os.environ.get("ENABLE_ISOLATION", "0") == "1"
        if not isolation_enabled:
            return True, "Permissive-Phase1-Compatible"

        trusted_token = get_trusted_edge_token()
        incoming_token = self.headers.get("X-CN-Edge-Token", "")
        if trusted_token and incoming_token == trusted_token:
            return True, "Allowed-Edge-Authenticated"
        return False, "Blocked-Direct-Access-Denied"

    def do_GET(self):
        authorized, isolation_status = self.is_authorized()

        if not authorized:
            body = json.dumps({
                "error": "Access Denied: Direct backend access forbidden by Service Isolation Policy",
                "backend": "B",
                "isolation_status": isolation_status
            }).encode()
            self.send_response(403)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("X-Backend", "B")
            self.send_header("X-Isolation-Status", isolation_status)
            self.end_headers()
            self.wfile.write(body)
            return

        if self.path == "/":
            body = b"Backend B - CN Project\n"
            content_type = "text/plain"

        elif self.path == "/api/status":
            body = json.dumps({
                "backend": "B",
                "status": "ok",
                "isolation": isolation_status
            }).encode()
            content_type = "application/json"

        elif self.path == "/health":
            body = json.dumps({"backend": "B", "health": "healthy"}).encode()
            content_type = "application/json"

        else:
            body = b"Not Found\n"
            content_type = "text/plain"
            self.send_response(404)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("X-Backend", "B")
            self.send_header("X-Isolation-Status", isolation_status)
            self.end_headers()
            self.wfile.write(body)
            return

        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("X-Backend", "B")
        self.send_header("X-Isolation-Status", isolation_status)
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        print("Backend B:", format % args, flush=True)

if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", 3002), Handler)
    print("Backend B listening on http://0.0.0.0:3002", flush=True)
    server.serve_forever()
