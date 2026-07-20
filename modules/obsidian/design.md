# Obsidian Module Design

## Purpose

Enable the official Obsidian CLI (`obsidian`) to be used from the command line and from Agent Skills by declaratively configuring the `commandLineInterface` setting in each vault's `app.json`. This avoids manual GUI setup (Settings → General → Command line interface) on every machine.

## Non-Goals

- Installing or managing the Obsidian GUI application itself.
- Managing vault content (notes, templates, plugins) or Obsidian settings beyond the CLI toggle.
- Providing a full Obsidian plugin development workflow (eval, devtools, etc.) — those are documented in the Agent Skill `SKILL.md` but are out of scope for the Nix module.
- Supporting non-macOS platforms (the `osascript` call in the activation script is macOS-specific).

## Why This Structure

- **Single-file module** (`home.nix` with both `options` and `config`): The module has one small function. Splitting it into `options.nix` and `home.nix` would add import boilerplate without benefit.
- **`default-config/flake.nix`**: Follows the same `--override-input` pattern as `modules/storage/default-config`. This is the established dotfiles convention for local-overridable configs that must survive Nix evaluation inside the store (where `builtins.pathExists` to the repo root fails).
- **Agent Skill in `skills/project/obsidian-manager/`**: The `obsidian` CLI is best exercised by an Agent calling its subcommands. The Skill provides the task descriptions; the module provides the environment (PATH, activation) that makes those commands work.

## Rejected Alternatives

- **GUI-only activation**: The official Obsidian documentation describes enabling the CLI through Settings → General. This was rejected because it requires manual intervention on every machine and cannot be reproduced.
- **AppleScript automation alone**: Using `osascript` to click through the Obsidian settings dialog is fragile (depends on UI layout, localization). Replaced in favor of directly patching `app.json` with `jq`, which is deterministic and idempotent. AppleScript is retained only to ensure Obsidian is running before the `jq` patch (the app must not be quit for the CLI to be registered).
- **`builtins.pathExists` in `modules/home.nix`**: A conditional import using `builtins.pathExists ../.local/obsidian/home.nix` was attempted first. It fails because Nix copies source files into the store, and the store path does not include `.local/` (gitignored). The `--override-input` pattern was the established workaround.
- **Host-profile `darwin.nix`**: Setting `obsidian.vaults` in each host's `modules/<host>/darwin.nix` was rejected because vault paths are per-user, not per-machine hardware — the user may have the same vaults on multiple hosts.
- **List of vault strings over submodule**: `obsidian.vaults` is a `listOf str` rather than a `listOf (submodule {...})`. This was chosen because no per-vault options beyond the path exist yet. The type can be upgraded to submodule entries later if needed.

## Constraints

- **Obsidian app must be running**: The `obsidian` CLI communicates with the running Obsidian process. The activation script calls `osascript` to launch the app if it is not already running.
- **`--override-input obsidian-vault-config`**: The `darwin-rebuild.sh` script passes this flag when `.local/obsidian-vault/` exists. Without it, the module compiles but remains disabled (default config).
- **macOS only**: The `osascript` call and the `~/.local/bin` symlink path are macOS-specific. The module function is gated on `home-manager` which supports only Darwin and Linux, but the AppleScript step will fail silently on Linux (the check uses `command -v osascript`).
- **`jq` must be present on the system at activation time**: Used to patch `app.json`. Not required at build time since the script runs during `home.activation`.
