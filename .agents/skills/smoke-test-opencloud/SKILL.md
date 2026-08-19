---
name: smoke-test-opencloud
description: Run smoke tests to verify OpenCloud is running and accessible after deployment.
---

# OpenCloud Smoke Test

Verifies that OpenCloud is running correctly after `darwin-rebuild switch`.

## Usage

Run from the repository root:

```bash
.agents/skills/smoke-test-opencloud/scripts/test.sh
```

## Checks Performed

1. **Container Status**: Verifies the `opencloud` container is in `running` state via `docker compose -p opencloud ps`.
2. **Health Endpoint**: Curls the health endpoint on localhost to confirm HTTP 200:
   - OpenCloud: `http://127.0.0.1:9200/health`
3. **Caddy Reverse Proxy**: Verifies HTTPS access through Caddy:
   - `https://opencloud.<hostname>.internal`

## When to Use

- After `darwin-rebuild switch` to verify OpenCloud deployed correctly.
- When debugging OpenCloud service issues.
