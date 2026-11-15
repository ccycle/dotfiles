---
name: setup-local-storage
description: Create or repair the machine-local state under .local/ (storage volume roots and the user/dotfiles flake overrides). Use when a build fails because an external volume or the invoking user is not configured, or when an external drive is renamed or replaced.
---

# Setup Local Storage

This skill owns the gitignored, machine-local `.local/` state:

- `setup-local-storage.sh` writes `.local/storage/flake.nix`, which sets the
  external volume root for services like Immich, OpenCloud, GitLab, and
  Monitoring.
- `ensure-local.sh` restores/corrects the rest of `.local/` for the current
  checkout: copies `storage/` and `obsidian-vault/` from the main checkout (a
  linked worktree starts without them), repoints the `dotfiles` override at
  the current checkout, and regenerates the `user` identity. `verify-change`,
  `darwin-rebuild.sh`, and `pocket-id-register-clients.sh` call it
  automatically, so run it by hand only when debugging.

## Usage

```bash
.agents/skills/setup-local-storage/scripts/setup-local-storage.sh <service>=<path> [...]

# Report (or repair) the rest of .local/ without rebuilding
.agents/skills/setup-local-storage/scripts/ensure-local.sh --check
.agents/skills/setup-local-storage/scripts/ensure-local.sh
```

## Behavior

When invoked without arguments from the user, auto-detect the volume:

1. List mounted volumes under `/Volumes/` (excluding system volumes like `Macintosh HD`).
2. If exactly one external volume is found, use it.
3. If multiple are found, ask the user which one to use.
4. If none are found, ask the user to provide the path manually.

Then pass each service that needs storage explicitly, e.g.
`forgejo=/Volumes/WD_BLACK immich=/Volumes/WD_BLACK`. Services the user does
not name keep their existing entry.

## Examples

```bash
# Direct usage
.agents/skills/setup-local-storage/scripts/setup-local-storage.sh immich=/Volumes/WD_BLACK

# Auto-detect (skill logic)
# 1. ls /Volumes/ to find external volumes
# 2. Run the script with <service>=<chosen volume> for each service
```

## When to Use

- On initial setup of a new machine that has external storage for services
- When an external drive is renamed or replaced
- When `verify-change` fails with "requires custom.storage.volumeRoot to be set"
