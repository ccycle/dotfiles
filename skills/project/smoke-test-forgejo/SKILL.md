---
name: smoke-test-forgejo
description: Run smoke tests to verify Forgejo is running and accessible after deployment.
---

# Forgejo Smoke Test

Verifies that Forgejo is running correctly after `darwin-rebuild switch`. Forgejo is only enabled on `mac-mini-m4-pro`.

## Usage

Run from the repository root:

```bash
skills/project/smoke-test-forgejo/scripts/test.sh
```

## Checks Performed

1. **Container Status**: Verifies the `forgejo` container is in `running` state via `docker compose -p forgejo ps`.
2. **Health Endpoint**: Curls the readiness endpoint on localhost to confirm HTTP 200:
   - Forgejo: `http://127.0.0.1:3000/api/healthz`
3. **Caddy Reverse Proxy**: Verifies HTTPS access through Caddy:
   - `https://forgejo.<hostname>.internal`

## When to Use

- After `darwin-rebuild switch` to verify Forgejo deployed correctly.
- When debugging Forgejo service issues.
- This does not check GitHub push-mirror status — inspect `/var/log/forgejo-mirror-bootstrap.log` and the repository's Mirror Settings page for that.
