---
name: smoke-test-lm-studio
description: Run smoke tests to verify LM Studio server is running and accessible via Caddy reverse proxy after deployment.
---

# LM Studio Smoke Test

Verifies that the LM Studio OpenAI-compatible API server is running and reachable through the Caddy HTTP reverse proxy. LM Studio server is only enabled on `mac-mini-m4-pro`.

## Usage

Run from the repository root:

```bash
skills/project/smoke-test-lm-studio/scripts/test.sh
```

## Checks Performed

1. **LM Studio Server**: Curls the local `/v1/models` endpoint on `127.0.0.1:1234` to confirm the server is running.
2. **Caddy Reverse Proxy (HTTP)**: Verifies HTTP access through Caddy at `http://llm.<hostname>.internal/v1/models`.

## When to Use

- After `darwin-rebuild switch` to verify LM Studio server deployed correctly.
- When debugging LM Studio API connectivity from tailnet clients.
- Note: The `lms` CLI must have been bootstrapped (launch LM Studio app once) before the launchd agent can start the server.
