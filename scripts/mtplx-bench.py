#!/usr/bin/env python3
"""Measure tokens/sec for the local MTPLX server with a fixed prompt.

Usage: python3 mtplx-bench.py [--base http://127.0.0.1:8881] [--n 3] [--max-tokens 1024]
"""
import argparse
import json
import time
import urllib.request

FIXED_MESSAGES = [
    {
        "role": "user",
        "content": (
            "Write a detailed, technical explanation of how speculative "
            "decoding with multi-token prediction (MTP) works in modern "
            "transformer language models. Cover the draft model, the "
            "verification step, acceptance/rejection of draft tokens, "
            "how it interacts with KV cache, and its effect on decoding "
            "throughput. Be thorough and use concrete examples."
        ),
    }
]


def stream_once(base_url: str, model: str, max_tokens: int) -> dict:
    body = json.dumps(
        {
            "model": model,
            "messages": FIXED_MESSAGES,
            "max_tokens": max_tokens,
            "temperature": 0,
            "stream": True,
        }
    ).encode()
    req = urllib.request.Request(
        f"{base_url}/v1/chat/completions",
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    t_start = time.monotonic()
    first_token_at = None
    prev = None
    usage = {}
    with urllib.request.urlopen(req) as resp:
        for line in resp:
            line = line.decode().strip()
            if not line.startswith("data: "):
                continue
            payload = line[6:]
            if payload == "[DONE]":
                break
            try:
                chunk = json.loads(payload)
            except json.JSONDecodeError:
                continue
            if chunk.get("usage"):
                usage = chunk["usage"]
            for choice in chunk.get("choices", []):
                delta = choice.get("delta", {})
                if delta.get("content"):
                    if first_token_at is None:
                        first_token_at = time.monotonic()
                    prev = len(delta["content"])
        t_end = time.monotonic()
    ttft = (first_token_at - t_start) if first_token_at else None
    generation = (t_end - first_token_at) if first_token_at else (t_end - t_start)
    # Fallback to usage.prompt_tokens for speed computation when usage is absent
    return {
        "ttft_s": round(ttft, 3) if ttft else None,
        "wall_s": round(t_end - t_start, 3),
        "gen_s": round(generation, 3),
        "completion_tokens": usage.get("completion_tokens"),
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default="http://127.0.0.1:8881")
    ap.add_argument("--model", default="qwen/qwen3.8-27b-mtplx")
    ap.add_argument("--n", type=int, default=3)
    ap.add_argument("--max-tokens", type=int, default=1024)
    args = ap.parse_args()

    req = urllib.request.Request(f"{args.base}/v1/models")
    with urllib.request.urlopen(req) as resp:
        models = json.loads(resp.read())["data"]
    print(f"server models: {[m['id'] for m in models]}", flush=True)

    results = []
    for i in range(args.n):
        r = stream_once(args.base, args.model, args.max_tokens)
        toks = r["completion_tokens"] or 0
        r["tokens_per_s"] = round(toks / r["gen_s"], 2) if r["gen_s"] else None
        results.append(r)
        print(f"run {i + 1}/{args.n}: {json.dumps(r)}", flush=True)

    rates = [r["tokens_per_s"] for r in results if r["tokens_per_s"]]
    if rates:
        print(
            f"BEST: {max(rates)} tok/s  MIN: {min(rates)} tok/s  "
            f"MEAN: {sum(rates) / len(rates):.2f} tok/s"
        )


if __name__ == "__main__":
    main()