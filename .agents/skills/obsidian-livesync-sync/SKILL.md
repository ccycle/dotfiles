---
name: obsidian-livesync-sync
description: Trigger Obsidian LiveSync synchronization via Advanced URI from the CLI. Use when the user asks to sync their Obsidian vault immediately.
---

# Obsidian LiveSync Sync

Triggers a one-shot replication cycle of the Obsidian LiveSync plugin via the Advanced URI plugin's `commandid` endpoint.

## Prerequisites

- Obsidian must be running (check with `pgrep -fl Obsidian`)
- [Advanced URI](https://github.com/Vinzent03/obsidian-advanced-uri) plugin installed in the vault
- [Self-hosted LiveSync](https://github.com/vrtmrz/obsidian-livesync) plugin installed and configured

## Vault

| Field                | Value                                  |
| -------------------- | -------------------------------------- |
| Path                 | `$HOME/Obsidian/zettelkasten`          |
| Name                 | `zettelkasten`                         |
| Default sync command | `obsidian-livesync:livesync-replicate` |

## Usage

```bash
.claude/skills/obsidian-livesync-sync/scripts/sync.sh
```

Run a different LiveSync command:

```bash
.claude/skills/obsidian-livesync-sync/scripts/sync.sh --command obsidian-livesync:livesync-toggle
```

## Verification

After triggering sync, read a note from the vault to confirm content is up-to-date:

```bash
cat "$HOME/Obsidian/zettelkasten/<note-name>.md"
```

## Other Available Commands

| Command ID                              | Description                    |
| --------------------------------------- | ------------------------------ |
| `obsidian-livesync:livesync-replicate`  | Run one-shot replication cycle |
| `obsidian-livesync:livesync-toggle`     | Toggle LiveSync on/off         |
| `obsidian-livesync:livesync-abortsync`  | Abort running synchronization  |
| `obsidian-livesync:livesync-suspendall` | Toggle all sync on/off         |
| `obsidian-livesync:livesync-scan-files` | Scan vault files               |
| `obsidian-livesync:view-log`            | View LiveSync log              |

## Files

| Path              | Purpose                |
| ----------------- | ---------------------- |
| `SKILL.md`        | This file              |
| `scripts/sync.sh` | Script to trigger sync |
