---
name: smoke-test-herdr-reviewr
description: Run smoke tests to verify the herdr-reviewr plugin is installed, configured, and launchable after deployment.
---

# herdr-reviewr Smoke Test

Verifies that the `persiyanov.reviewr` plugin (declared in `modules/herdr/home.nix`) is installed
in the running herdr server, its config symlinks resolve into the repo, and it actually opens a
pane when invoked — driven entirely through herdr's own socket API (`herdr pane` / `herdr
workspace` / `herdr plugin`), the same primitives herdr uses to control panes for AI agents.

## Usage

Run from the repository root, with the herdr server already running:

```bash
.agents/skills/smoke-test-herdr-reviewr/scripts/test.sh
```

Requires `jq`.

## Checks Performed

1. **herdr Server**: `herdr status` succeeds.
2. **Plugin Installation**: `herdr plugin list --json` lists `persiyanov.reviewr` (confirms the
   `home.activation.herdr-reviewr-install` script ran successfully).
3. **Config Symlinks**:
   - `~/.config/herdr/config.toml` is a symlink and defines the `persiyanov.reviewr.toggle`
     keybinding.
   - `~/.config/herdr/plugins/config/persiyanov.reviewr/config.toml` is a symlink into
     `modules/herdr/reviewr-config.toml`.
4. **Live Plugin Invocation**: creates a disposable scratch workspace (`herdr workspace create`),
   invokes `herdr plugin action invoke open --plugin persiyanov.reviewr`, and confirms a new pane
   appeared via `herdr pane list --workspace <id>`. The scratch workspace is closed on exit
   (`trap cleanup EXIT`), regardless of pass/fail.

## When to Use

- After `darwin-rebuild switch` to verify herdr-reviewr deployed correctly.
- When debugging why the `prefix+ctrl+r` toggle or `persiyanov.reviewr.toggle` keybinding isn't opening
  the sidebar.

## Notes

- Check 4 asserts on pane count only (not on reviewr's rendered UI content), since panes are
  read as plain text/ANSI through `herdr pane read` and reviewr's exact footer/hint text is not a
  stable contract to assert against.
- The `open` action targets herdr's implicit "current" context, which is why the scratch
  workspace is created with `--focus`. If a future herdr-reviewr release changes how plugin
  actions resolve their target pane, check 4 may need a `herdr pane focus` step first.
