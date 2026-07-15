---
name: setup-local-storage
description: Create or update the machine-local storage configuration (.local/storage/flake.nix) that sets the external volume root path for services like Immich, OpenCloud, GitLab, and Monitoring.
---

# Setup Local Storage

This skill creates the `.local/storage/flake.nix` file that tells the dotfiles which external volume to use for service data storage. The file is gitignored and machine-local.

## Usage

```bash
scripts/setup-local-storage.sh <volume-root>
```

## Behavior

When invoked without arguments from the user, auto-detect the volume:

1. List mounted volumes under `/Volumes/` (excluding system volumes like `Macintosh HD`).
2. If exactly one external volume is found, use it.
3. If multiple are found, ask the user which one to use.
4. If none are found, ask the user to provide the path manually.

When the user provides a specific path, pass it directly to the script.

## Examples

```bash
# Direct usage
scripts/setup-local-storage.sh /Volumes/WD_BLACK

# Auto-detect (skill logic)
# 1. ls /Volumes/ to find external volumes
# 2. Pass the chosen volume to the script
```

## When to Use

- On initial setup of a new machine that has external storage for services
- When an external drive is renamed or replaced
- When `verify-change` fails with "requires custom.storage.volumeRoot to be set"
