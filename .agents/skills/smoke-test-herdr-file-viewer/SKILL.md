---
name: smoke-test-herdr-file-viewer
description: Run smoke tests to verify the herdr-file-viewer plugin is installed, configured, and launchable after deployment.
---

# herdr-file-viewer Smoke Test

Verifies that the `herdr-file-viewer` plugin (installed by [modules/herdr/install-plugins.sh](../../../modules/herdr/install-plugins.sh)) is installed in
the running herdr server, its keybindings resolve from the repo-managed `config.toml`, and it
actually opens a pane when invoked — driven entirely through herdr's own socket API (`herdr pane` /
`herdr workspace` / `herdr plugin`), the same primitives herdr uses to control panes for AI agents.

## Usage

Run from the repository root, with the herdr server already running:

```bash
.agents/skills/smoke-test-herdr-file-viewer/scripts/test.sh
```

Requires `jq`.

## Checks Performed

1. **herdr Server**: `herdr status` succeeds.
2. **Plugin Installation**: `herdr plugin list --json` has an entry whose `plugin_id` is
   `herdr-file-viewer`.
3. **Config Symlink**: `~/.config/herdr/config.toml` is a symlink and defines both the
   `open-file-viewer` and `open-file-viewer-tab` shell keybindings.
4. **Live Plugin Invocation**: creates a disposable scratch workspace (`herdr workspace create`),
   invokes `herdr plugin action invoke open-file-viewer --plugin herdr-file-viewer`, and polls
   `herdr pane list --workspace <id>` for up to 10 seconds until a new pane appears (the action
   returns before the pane opens). The scratch workspace is closed on
   exit (`trap cleanup EXIT`), regardless of pass/fail.

## When to Use

- After running [modules/herdr/install-plugins.sh](../../../modules/herdr/install-plugins.sh) to verify herdr-file-viewer installed correctly.
- When debugging why the `prefix+f` / `prefix+shift+f` bindings aren't opening the file viewer.

## Notes

- No plugin-specific config.toml is symlinked for this plugin (unlike herdr-reviewr); it runs on
  upstream defaults, so there is no config-symlink check beyond the base `~/.config/herdr/config.toml`.
- Check 4 asserts on pane count only (not on the file viewer's rendered UI content), matching the
  same reasoning as the herdr-reviewr smoke test: pane content is read as plain text/ANSI and exact
  UI text is not a stable contract to assert against.
