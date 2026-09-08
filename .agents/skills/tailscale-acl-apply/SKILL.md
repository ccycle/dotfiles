---
name: tailscale-acl-apply
description: Review and apply the Tailscale ACL policy (modules/tailscale/policy.hujson) via OpenTofu, using scripts/tailscale-acl-apply.sh. Use when changing the ACL policy file, or when asked to apply/sync Tailscale ACLs.
---

# Tailscale ACL Apply

`modules/tailscale/policy.hujson` is the single source of truth for the
tailnet's ACL policy. It used to be applied by hand-copying into the
Tailscale admin console; it is now applied via OpenTofu
(`modules/tailscale/terraform/`), reviewed with `tofu plan` before every
apply. See `modules/tailscale/design.md` ("Why ACL Apply Stays a Human
Step") for the rationale.

## When To Use

- Changing `modules/tailscale/policy.hujson` and needing to push it live.
- Syncing the live tailnet ACL after a `git pull` that changed the policy.
- One-time: bootstrapping OpenTofu management of an already-live ACL.

## Prerequisites

- `opentofu` available (`modules/terraform/home.nix`, installed via
  home-manager on any host that imports `modules/home.nix`).
- A Tailscale OAuth client, created once by hand (Settings -> OAuth
  clients in the Tailscale admin console), scoped to the narrowest
  ACL-write scope available — check the current scope list at
  https://tailscale.com/kb/1623 rather than assuming a name here.
- That OAuth client's ID/secret stored in `modules/tailscale/secrets.yaml`:
  ```bash
  .agents/skills/credentials-manager/scripts/edit-secrets.sh modules/tailscale/secrets.yaml
  # add: tailscale_tf_oauth_client_id, tailscale_tf_oauth_client_secret
  ```
  (`tailscale_tailnet` already exists in this file for the Split DNS
  feature and is reused as-is.)
- The operator holds this repo's sops age key via `rbw` (see CLAUDE.md,
  "Age Key Management with rbw"); `rbw unlock` first if needed.

## One-Time Bootstrap (adopting an already-live ACL)

Run once, before ever calling `--apply`, so the live policy is imported
rather than silently overwritten:

```bash
cd modules/tailscale/terraform
tofu init
tofu import tailscale_acl.this acl
```

Then run `scripts/tailscale-acl-apply.sh` (no `--apply`) and confirm the
plan shows no diff (or only a cosmetic/comment diff) against the live
policy before treating this as adopted.

## Normal Workflow

1. Edit `modules/tailscale/policy.hujson`.
2. `scripts/tailscale-acl-apply.sh` — runs `tofu init`, `tofu fmt -check`,
   `tofu validate`, and `tofu plan`. Read the plan output.
3. If the diff is what you expect: `scripts/tailscale-acl-apply.sh --apply`
   — this re-shows the plan and requires typing `yes` at the OpenTofu
   prompt (still no unattended apply; see design.md's rationale).
4. Commit the changed `policy.hujson` (and `.terraform.lock.hcl` if it
   changed) to git.

## Notes / Caveats

- CI/automated apply is explicitly out of scope — see
  `modules/tailscale/design.md`. This remains a human-run command.
- `terraform.tfstate` and `.terraform/` are local-only and gitignored
  (single-operator setup, see `modules/tailscale/design.md`); only
  `.terraform.lock.hcl` and the `.tf` files are checked in.
- Pocket ID's OIDC clients are a separate, larger effort (that module's
  clients are the single source of truth for 4 other service modules) and
  are explicitly not covered by this skill.
