---
name: smoke-test-llm-server
description: Run smoke tests to verify the llama-swap LLM server is running and accessible via Caddy reverse proxy after deployment.
---

# LLM Server Smoke Test

Verifies that the llama-swap server is running and reachable through the Caddy HTTP reverse proxy. The LLM server is only enabled on `mac-mini-m4-pro`.

## Usage

Run from the repository root:

```bash
skills/project/smoke-test-llm-server/scripts/test.sh
```

## Checks Performed

1. **llama-swap Health**: Curls `/health` on `127.0.0.1:8880` to confirm llama-swap is running.
2. **llama-swap Models**: Curls `/v1/models` on `127.0.0.1:8880` to list available models.
3. **Caddy Reverse Proxy (HTTP)**: Verifies HTTP access through Caddy at `http://llm.<hostname>.internal/v1/models`.

## When to Use

- After `darwin-rebuild switch` to verify the LLM server deployed correctly.
- When debugging LLM API connectivity from tailnet clients.
- Note: First run after deploy may take a while as GGUF models are downloaded.
