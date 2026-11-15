---
name: smoke-test-llm-server
description: Verify the llama-swap LLM server is running and accessible via the Caddy reverse proxy, and benchmark its tokens/sec. Use after deployment or when debugging LLM server health, reachability, or throughput.
---

# LLM Server Smoke Test

Verifies that the llama-swap server is running and reachable through the Caddy HTTP reverse proxy. The LLM server is only enabled on `mac-mini-m4-pro`.

## Usage

Run from the repository root:

```bash
.agents/skills/smoke-test-llm-server/scripts/test.sh
```

## Checks Performed

1. **llama-swap Health**: Curls `/health` on `127.0.0.1:8880` to confirm llama-swap is running.
2. **llama-swap Models**: Curls `/v1/models` on `127.0.0.1:8880` to list available models.
3. **Caddy Reverse Proxy (HTTP)**: Verifies HTTP access through Caddy at `http://llm.<hostname>.internal/v1/models`.

## Throughput Benchmark (optional)

[mtplx-bench.py](scripts/mtplx-bench.py) measures
tokens/sec against a fixed prompt (`--base`, `--n`, `--max-tokens`). Use it to
compare model or server-config changes; it is not a pass/fail smoke test.

## When to Use

- After `darwin-rebuild switch` to verify the LLM server deployed correctly.
- When debugging LLM API connectivity from tailnet clients.
- Note: First run after deploy may take a while as GGUF models are downloaded.
