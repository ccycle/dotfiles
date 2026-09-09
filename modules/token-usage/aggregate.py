#!/usr/bin/env python3
"""Aggregates Claude Code and opencode token usage into a Prometheus
textfile, per chat/session, priced from a static local table.

Claude Code: reads ~/.claude/projects/**/*.jsonl transcripts (one file
per session/chat) and sums the Anthropic Messages API `usage` fields on
each assistant message, by model.

opencode: reads its own SQLite state db's `session` table directly -
opencode already tracks per-session cost/tokens/model there, so real
spend (session.cost) is used as-is. Zen free-tier sessions (provider
"opencode", model id ending "-free") have real cost 0; those additionally
get an approximate market-equivalent cost from the price table, labeled
approx="true" so it's never mistaken for real spend. Self-hosted local
inference (llamaswap/mtplx/mlx-server providers) has no meaningful market
price and is skipped for cost - only its token volume is reported.

Only chats active within RETENTION_DAYS are emitted, so the per-chat
label cardinality is naturally bounded by roughly Prometheus's own
scrape-config retention window instead of growing forever.
"""
import argparse
import json
import sqlite3
import time
from pathlib import Path

RETENTION_DAYS = 30
USD_PER_TOKEN_KEYS = ("input", "output", "cache_write", "cache_read")


def load_prices(path):
    return json.loads(Path(path).read_text())


def price_cost(price_table, key, tokens):
    rates = price_table.get(key)
    if not rates:
        return None
    cost = 0.0
    for k in USD_PER_TOKEN_KEYS:
        rate = rates.get(k)
        if rate is not None:
            cost += tokens.get(k, 0) / 1_000_000 * rate
    return cost


def claude_code_usage(projects_dir, cutoff_ts):
    """Yields (session_id, model, tokens_dict) - one per (session, model) pair."""
    root = Path(projects_dir)
    if not root.is_dir():
        return
    for jsonl in root.glob("*/*.jsonl"):
        try:
            if jsonl.stat().st_mtime < cutoff_ts:
                continue
        except OSError:
            continue
        session_id = jsonl.stem
        totals = {}
        with jsonl.open() as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                except json.JSONDecodeError:
                    continue
                msg = entry.get("message")
                if not isinstance(msg, dict):
                    continue
                usage = msg.get("usage")
                model = msg.get("model")
                if not usage or not model:
                    continue
                t = totals.setdefault(
                    model, {"input": 0, "output": 0, "cache_write": 0, "cache_read": 0}
                )
                t["input"] += usage.get("input_tokens", 0)
                t["output"] += usage.get("output_tokens", 0)
                t["cache_write"] += usage.get("cache_creation_input_tokens", 0)
                t["cache_read"] += usage.get("cache_read_input_tokens", 0)
        for model, tokens in totals.items():
            yield session_id, model, tokens


def opencode_usage(db_path, cutoff_ts):
    """Yields (session_id, provider, model_id, real_cost, tokens_dict) per session."""
    if not Path(db_path).exists():
        return
    cutoff_ms = int(cutoff_ts * 1000)
    conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    try:
        rows = conn.execute(
            "SELECT id, model, cost, tokens_input, tokens_output, "
            "tokens_cache_read, tokens_cache_write "
            "FROM session WHERE model IS NOT NULL AND time_updated >= ?",
            (cutoff_ms,),
        ).fetchall()
    finally:
        conn.close()
    for session_id, model_json, cost, ti, to, tcr, tcw in rows:
        try:
            model = json.loads(model_json)
        except (json.JSONDecodeError, TypeError):
            continue
        tokens = {
            "input": ti or 0,
            "output": to or 0,
            "cache_read": tcr or 0,
            "cache_write": tcw or 0,
        }
        yield session_id, model.get("providerID", "unknown"), model.get("id", "unknown"), cost or 0.0, tokens


def prom_escape(s):
    return s.replace("\\", "\\\\").replace('"', '\\"')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--prices", required=True)
    ap.add_argument("--claude-projects-dir", required=True)
    ap.add_argument("--opencode-db", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    prices = load_prices(args.prices)
    anthropic_prices = prices.get("anthropic", {})
    zen_approx_prices = prices.get("opencode_zen_free_approx", {})
    cutoff_ts = time.time() - RETENTION_DAYS * 86400

    cost_lines = [
        '# HELP token_usage_cost_usd Approximate USD cost of a chat/session\'s token usage, from a static local price table (approx="true" for opencode Zen free-tier sessions, which have no real cost).',
        "# TYPE token_usage_cost_usd gauge",
    ]
    token_lines = [
        "# HELP token_usage_tokens_total Input+output token count for a chat/session.",
        "# TYPE token_usage_tokens_total gauge",
    ]

    for session_id, model, tokens in claude_code_usage(args.claude_projects_dir, cutoff_ts):
        session_label = prom_escape(session_id)
        model_label = prom_escape(model)
        total_tokens = tokens["input"] + tokens["output"]
        token_lines.append(
            f'token_usage_tokens_total{{tool="claude-code",session="{session_label}",model="{model_label}"}} {total_tokens}'
        )
        cost = price_cost(anthropic_prices, model, tokens)
        if cost is not None:
            cost_lines.append(
                f'token_usage_cost_usd{{tool="claude-code",session="{session_label}",model="{model_label}",approx="false"}} {cost:.6f}'
            )

    for session_id, provider, model_id, real_cost, tokens in opencode_usage(
        args.opencode_db, cutoff_ts
    ):
        session_label = prom_escape(session_id)
        model_label = prom_escape(model_id)
        total_tokens = tokens["input"] + tokens["output"]
        token_lines.append(
            f'token_usage_tokens_total{{tool="opencode",session="{session_label}",model="{model_label}"}} {total_tokens}'
        )
        if real_cost > 0:
            cost_lines.append(
                f'token_usage_cost_usd{{tool="opencode",session="{session_label}",model="{model_label}",approx="false"}} {real_cost:.6f}'
            )
        elif provider == "opencode" and model_id.endswith("-free"):
            approx = price_cost(zen_approx_prices, model_id, tokens)
            if approx is not None:
                cost_lines.append(
                    f'token_usage_cost_usd{{tool="opencode",session="{session_label}",model="{model_label}",approx="true"}} {approx:.6f}'
                )
        # Other zero-cost sessions (self-hosted llamaswap/mtplx/mlx-server
        # providers) have no meaningful market price - cost intentionally
        # omitted, token volume above still counts them.

    out = "\n".join(cost_lines + token_lines) + "\n"
    tmp = args.out + ".tmp"
    Path(tmp).write_text(out)
    Path(tmp).rename(args.out)


if __name__ == "__main__":
    main()
