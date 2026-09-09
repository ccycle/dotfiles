#!/usr/bin/env python3
"""Alertmanager webhook receiver for self-healing detection.

Alertmanager's payload is not parsed for alert detail - self-healing-
daemon.sh already re-queries Prometheus's /api/v1/alerts for the full
current firing set on every run, so the webhook only needs to serve as a
"something just started firing" wake-up signal. Responds immediately
(before Alertmanager's own webhook timeout) and runs the daemon script in
the background.
"""
import http.server
import os
import subprocess
import sys

DAEMON_SCRIPT = sys.argv[1] if len(sys.argv) > 1 else None
PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 9096


class Handler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        if length:
            self.rfile.read(length)  # drain the body, content is unused
        self.send_response(202)
        self.end_headers()
        subprocess.Popen(
            ["bash", DAEMON_SCRIPT],
            env=os.environ.copy(),
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )

    def log_message(self, fmt, *args):
        pass  # self-healing-daemon.sh's own jq-JSON logging covers this


def main():
    if not DAEMON_SCRIPT:
        raise SystemExit("usage: webhook-listener.py <daemon-script> [port]")
    server = http.server.HTTPServer(("127.0.0.1", PORT), Handler)
    server.serve_forever()


if __name__ == "__main__":
    main()
