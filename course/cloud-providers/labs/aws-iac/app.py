#!/usr/bin/env python3
"""Dependency-free teaching service; public configuration, no AWS access."""

import argparse
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8080)
    parser.add_argument("--config", type=Path)
    args = parser.parse_args()
    config = {"provider": "aws", "lab_id": "local", "message": "Hello from AWS and UPC"}
    if args.config:
        config = json.loads(args.config.read_text(encoding="utf-8"))
    if not isinstance(config, dict) or any(
        not isinstance(config.get(key), str) or not config[key]
        for key in ("provider", "lab_id", "message")
    ):
        parser.error("Configuration requires provider, lab_id and message as nonempty strings")
    if not 1 <= args.port <= 65535:
        parser.error("Port must be between 1 and 65535")

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self) -> None:
            if self.path not in ("/", "/health"):
                self.send_error(404)
                return
            payload = {**config, "status": "ok"}
            body = (json.dumps(payload, ensure_ascii=False) + "\n").encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)

    server = ThreadingHTTPServer((args.host, args.port), Handler)
    try:
        print(f"Listening on http://{args.host}:{args.port}/", flush=True)
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
