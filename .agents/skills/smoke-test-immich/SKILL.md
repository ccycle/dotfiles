---
name: smoke-test-immich
description: Run smoke tests to verify Immich is running and accessible after deployment.
---

# Immich Smoke Test

Verifies that the Immich stack (server, machine learning, Redis, PostgreSQL) is running correctly after `darwin-rebuild switch`.

## Usage

Run from the repository root:

```bash
.agents/skills/smoke-test-immich/scripts/test.sh
```

## Checks Performed

1. **Container Status**: Verifies all 4 Immich containers are in `running` state via `docker compose -p immich ps`.
2. **Health Endpoint**: Curls the server health endpoint on localhost to confirm HTTP 200:
   - Immich Server: `http://127.0.0.1:2283/api/server/ping`
3. **Caddy Reverse Proxy**: Verifies HTTPS access through Caddy:
   - `https://immich.<hostname>.internal`

## When to Use

- After `darwin-rebuild switch` to verify the Immich stack deployed correctly.
- When debugging Immich service issues.
