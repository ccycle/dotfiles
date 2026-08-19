---
name: smoke-test-gitlab
description: Run smoke tests to verify GitLab CE is running and accessible after deployment.
---

# GitLab Smoke Test

Verifies that GitLab CE is running correctly after `darwin-rebuild switch`. GitLab is only enabled on `mac-mini-m4-pro`.

## Usage

Run from the repository root:

```bash
.agents/skills/smoke-test-gitlab/scripts/test.sh
```

## Checks Performed

1. **Container Status**: Verifies the `gitlab-ce` container is in `running` state via `docker compose -p gitlab ps`.
2. **Health Endpoint**: Curls the readiness endpoint on localhost to confirm HTTP 200:
   - GitLab: `http://127.0.0.1:8929/-/readiness`
3. **Caddy Reverse Proxy**: Verifies HTTPS access through Caddy:
   - `https://gitlab.<hostname>.internal`

## When to Use

- After `darwin-rebuild switch` to verify GitLab deployed correctly.
- When debugging GitLab service issues.
- Note: GitLab may take 5+ minutes to become healthy after initial deployment.
