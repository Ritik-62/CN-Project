from http.server import BaseHTTPRequestHandler, HTTPServer
import json

class Handler(BaseHTTPRequestHandler):

    def do_GET(self):
        if self.path == "/":
            body = b"Backend B - CN Project\n"
            content_type = "text/plain"

        elif self.path == "/api/status":
            body = json.dumps({
                "backend": "B",
                "status": "ok"
            }).encode()
            content_type = "application/json"

        else:
            body = b"Not Found\n"
            content_type = "text/plain"
            self.send_response(404)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("X-Backend", "B")
            self.end_headers()
            self.wfile.write(body)
            return

        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("X-Backend", "B")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        print("Backend B:", format % args)

server = HTTPServer(("0.0.0.0", 3002), Handler)

print("Backend B listening on http://0.0.0.0:3002")
server.serve_forever()
