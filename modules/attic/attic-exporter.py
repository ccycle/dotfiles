#!/usr/bin/env python3
"""Attic cache Prometheus exporter — queries the atticd SQLite database
and exposes cache metrics over HTTP for Prometheus to scrape."""

import argparse
import subprocess
import time
from http.server import HTTPServer, BaseHTTPRequestHandler


def query_db(db_path, sql):
    """Run a sqlite3 query and return the first cell value as a string."""
    result = subprocess.run(
        ["sqlite3", "-json", db_path, sql],
        capture_output=True, text=True, timeout=10,
    )
    if result.returncode != 0:
        raise RuntimeError(f"sqlite3 error: {result.stderr.strip()}")
    rows = __import__("json").loads(result.stdout) if result.stdout.strip() else []
    return rows[0] if rows else {}


def format_metrics(metrics):
    """Format a list of (name, help, type, value) tuples into Prometheus exposition text."""
    lines = []
    seen = set()
    for name, help_text, type_, value in metrics:
        if name not in seen:
            lines.append(f"# HELP {name} {help_text}")
            lines.append(f"# TYPE {name} {type_}")
            seen.add(name)
        lines.append(f"{name} {value}")
    return "\n".join(lines) + "\n"


def collect(db_path, storage_path):
    """Query the atticd database and filesystem to build metrics."""
    m = []

    try:
        row = query_db(db_path, "SELECT COUNT(*) AS v FROM cache_rows")
        m.append(("attic_cache_objects_total", "Total number of cache objects", "gauge", row.get("v", 0)))
    except Exception as e:
        print(f"attic-exporter: objects query failed: {e}")

    try:
        row = query_db(db_path, "SELECT COUNT(*) AS v FROM nar_rows")
        m.append(("attic_cache_nars_total", "Total number of NARs", "gauge", row.get("v", 0)))
    except Exception as e:
        print(f"attic-exporter: nars query failed: {e}")

    try:
        row = query_db(db_path, "SELECT COALESCE(SUM(nar_size), 0) AS v FROM cache_rows")
        m.append(("attic_cache_nars_bytes", "Total logical size of NARs in bytes", "gauge", row.get("v", 0)))
    except Exception as e:
        print(f"attic-exporter: nar_size query failed: {e}")

    try:
        row = query_db(db_path, "SELECT COALESCE(SUM(chunk_size), 0) AS v FROM chunk_rows")
        m.append(("attic_cache_chunks_bytes", "Total physical size of chunks in bytes", "gauge", row.get("v", 0)))
    except Exception as e:
        print(f"attic-exporter: chunk_size query failed: {e}")

    try:
        row = query_db(db_path, "SELECT COUNT(*) AS v FROM chunk_rows")
        m.append(("attic_cache_chunks_total", "Total number of chunks", "gauge", row.get("v", 0)))
    except Exception as e:
        print(f"attic-exporter: chunks query failed: {e}")

    try:
        result = subprocess.run(
            ["du", "-sb", storage_path],
            capture_output=True, text=True, timeout=30,
        )
        if result.returncode == 0:
            size = int(result.stdout.split()[0])
            m.append(("attic_cache_storage_bytes", "Size of the storage directory in bytes", "gauge", size))
        else:
            print(f"attic-exporter: du failed: {result.stderr.strip()}")
    except Exception as e:
        print(f"attic-exporter: du exception: {e}")

    try:
        row = query_db(db_path, "SELECT page_count * page_size AS v FROM pragma_page_count(), pragma_page_size()")
        m.append(("attic_cache_sqlite_bytes", "SQLite database file size in bytes", "gauge", row.get("v", 0)))
    except Exception as e:
        print(f"attic-exporter: sqlite size query failed: {e}")

    try:
        row = query_db(db_path, "SELECT COUNT(*) AS v FROM cache_rows WHERE last_accessed_at IS NULL")
        m.append(("attic_cache_objects_never_accessed", "Objects that have never been pulled", "gauge", row.get("v", 0)))
    except Exception as e:
        print(f"attic-exporter: never-accessed query failed: {e}")

    try:
        row = query_db(db_path, "SELECT COUNT(*) AS v FROM cache_rows WHERE last_accessed_at IS NOT NULL")
        m.append(("attic_cache_pulls_total", "Objects that have been accessed at least once", "gauge", row.get("v", 0)))
    except Exception as e:
        print(f"attic-exporter: pulls query failed: {e}")

    try:
        row = query_db(db_path, "SELECT COALESCE(MAX(created_at), '') AS v FROM cache_rows")
        ts = row.get("v", "")
        if ts:
            import datetime
            epoch = int(datetime.datetime.fromisoformat(ts).timestamp())
            m.append(("attic_cache_last_push_timestamp_seconds", "Unix timestamp of the most recent push", "gauge", epoch))
    except Exception as e:
        print(f"attic-exporter: last_push query failed: {e}")

    try:
        row = query_db(db_path, """
            SELECT
                COALESCE(SUM(nar_size), 0) AS logical,
                COALESCE(SUM(chunk_size), 0) AS physical
            FROM cache_rows
        """)
        logical = int(row.get("logical", 0) or 0)
        physical = int(row.get("physical", 0) or 0)
        ratio = logical / physical if physical > 0 else 0
        m.append(("attic_cache_dedup_ratio", "Deduplication ratio (logical / physical)", "gauge", f"{ratio:.2f}"))
    except Exception as e:
        print(f"attic-exporter: dedup query failed: {e}")

    return m


class MetricsHandler(BaseHTTPRequestHandler):
    db_path = ""
    storage_path = ""
    cache = None
    cache_ts = 0
    cache_ttl = 60

    def do_GET(self):
        if self.path != "/metrics":
            self.send_error(404)
            return
        now = time.time()
        if MetricsHandler.cache is not None and now - MetricsHandler.cache_ts < MetricsHandler.cache_ttl:
            body = MetricsHandler.cache
        else:
            body = format_metrics(collect(self.db_path, self.storage_path))
            MetricsHandler.cache = body
            MetricsHandler.cache_ts = now
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
        self.end_headers()
        self.write(body.encode())

    def write(self, data):
        self.wfile.write(data)

    def log_message(self, fmt, *args):
        pass


if __name__ == "__main__":
    p = argparse.ArgumentParser(description="Attic cache Prometheus exporter")
    p.add_argument("--db", default="/var/lib/atticd/server.db", help="Path to atticd SQLite database")
    p.add_argument("--storage", default="/var/lib/atticd/storage", help="Path to storage directory")
    p.add_argument("--port", type=int, default=9201, help="Listen port")
    p.add_argument("--cache-ttl", type=int, default=60, help="Seconds to cache metrics between scrapes")
    args = p.parse_args()
    MetricsHandler.db_path = args.db
    MetricsHandler.storage_path = args.storage
    MetricsHandler.cache_ttl = args.cache_ttl
    print(f"attic-exporter: listening on :{args.port}, db={args.db}")
    HTTPServer(("127.0.0.1", args.port), MetricsHandler).serve_forever()
