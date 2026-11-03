#!/usr/bin/env python3
"""Servicio docente sin dependencias, credenciales ni acceso a almacenamiento."""
import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path not in ("/", "/health"):
            self.send_error(404)
            return
        body = json.dumps({
            "service": "upc-cloud-03",
            "provider": os.environ.get("LAB_PROVIDER", "local"),
            "lab_id": os.environ.get("LAB_ID", "local"),
            "status": "ok",
        }, sort_keys=True).encode("utf-8") + b"\n"
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    ThreadingHTTPServer((os.environ.get("HTTP_HOST", "0.0.0.0"), 8080), Handler).serve_forever()
