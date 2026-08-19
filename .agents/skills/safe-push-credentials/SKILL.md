---
name: safe-push-credentials
description: Rotate and monitor the fine-grained GitHub PAT used by git-safe-push (modules/git/github/safe-push).
---

# Safe Push Credentials

Manages the lifecycle of the fine-grained PAT that `git-safe-push` uses to push
on the agent's behalf. See `modules/git/design.md` for why this credential
exists and what it is (and is not) trusted to do.

## Features

### 1. Check expiration

```bash
.agents/skills/safe-push-credentials/scripts/check-expiry.sh [threshold_days]
```

Reads the deployed token, asks the GitHub API for its expiration, and exits
non-zero if fewer than `threshold_days` (default 14) remain. Override the
token path with `TOKEN_FILE=<path>` if it differs from the default sops-nix
runtime location (`/run/secrets/github-agent-push-token`).

### 2. Rotate the token

```bash
.agents/skills/safe-push-credentials/scripts/rotate-token.sh
```

Fine-grained PATs can only be created through the GitHub web UI (no CLI/API
path exists for it), so this script cannot be fully automated: it prints the
exact settings to use, prompts for the newly created token, and writes it
into `modules/git/github/safe-push/secrets.yaml` via sops. It does not revoke
the old token — that step is manual and printed at the end.

## Policies

- Never print the token to stdout/logs outside the one prompt in
  `rotate-token.sh`; `check-expiry.sh` only ever reads it into a header, never
  echoes it.
- Rotation requires a human in the loop by construction (PAT creation is a
  browser-only action) — this is intentional, not a gap to automate away.
- After rotating, rebuild (`/darwin-rebuild`) before the new secret takes
  effect, and confirm with `check-expiry.sh`.
