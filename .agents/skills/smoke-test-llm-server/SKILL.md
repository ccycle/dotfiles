---
name: smoke-test-llm-server
description: Verify the Ollama LLM server is running and accessible via the Caddy reverse proxy, and benchmark its tokens/sec. Use after deployment or when debugging LLM server health, reachability, or throughput.
---

# LLM Server Smoke Test

Verifies that the Ollama server is running and reachable through the Caddy HTTP reverse proxy. The LLM server is only enabled on `mac-mini-m4-pro`.

## Usage

Run from the repository root:

```bash
.agents/skills/smoke-test-llm-server/scripts/test.sh
```

## Checks Performed

1. **Ollama Health**: Curls `/api/version` on `127.0.0.1:11434` to confirm Ollama is running.
2. **Ollama Models**: Curls `/v1/models` on `127.0.0.1:11434` to list available models.
3. **Caddy Reverse Proxy (HTTP)**: Verifies HTTP access through Caddy at `http://llm.<hostname>.internal/v1/models`.

## Throughput Benchmark (optional)

[mtplx-bench.py](scripts/mtplx-bench.py) measures
tokens/sec against a fixed prompt (`--base`, `--n`, `--max-tokens`). Use it to
compare model or server-config changes; it is not a pass/fail smoke test.

## When to Use

- After `darwin-rebuild switch` to verify the LLM server deployed correctly.
- When debugging LLM API connectivity from tailnet clients.
- Note: First run after deploy may take a while as catalog models are pulled; progress is in `/var/tmp/llm-server-models.log`.
