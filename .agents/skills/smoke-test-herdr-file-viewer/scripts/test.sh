#!/usr/bin/env bash
set -euo pipefail

# --- Configuration ---
PLUGIN_ID="herdr-file-viewer"
HERDR_CFG="$HOME/.config/herdr/config.toml"
WORKSPACE_ID=""
FAILED=0

# --- Helpers ---
pass() { echo "✅ $1"; }
fail() { echo "❌ $1"; FAILED=1; }

cleanup() {
  if [ -n "$WORKSPACE_ID" ]; then
    herdr workspace close "$WORKSPACE_ID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

# --- 1. herdr Server ---
echo "=== 🩺 herdr Server ==="

if ! herdr status >/dev/null 2>&1; then
  fail "herdr server is not running"
  echo ""
  echo "❌ Smoke test failed."
  exit 1
fi
pass "herdr server is running"

echo ""

# --- 2. Plugin Installation ---
echo "=== 🔌 Plugin Installation ==="

# Field name for the plugin's id in `herdr plugin list --json` is unconfirmed for this plugin
# (docs and herdr-reviewr's own smoke test disagree between "id" and "plugin_id"), so search all
# field values instead of asserting a specific key.
if herdr plugin list --json 2>/dev/null | jq -e --arg id "$PLUGIN_ID" '.result.plugins[] | to_entries[] | select(.value == $id)' >/dev/null 2>&1; then
  pass "$PLUGIN_ID is installed"
else
  fail "$PLUGIN_ID is not installed (run: herdr plugin install smarzban/herdr-file-viewer)"
fi

echo ""

# --- 3. Config Symlink ---
echo "=== 🔗 Config Symlink ==="

if [ -L "$HERDR_CFG" ] && grep -q "open-file-viewer" "$HERDR_CFG" && grep -q "open-file-viewer-tab" "$HERDR_CFG"; then
  pass "herdr config.toml is symlinked and defines the file-viewer keybindings"
else
  fail "herdr config.toml is missing, not a symlink, or missing the file-viewer keybindings"
fi

echo ""

# --- 4. Live Plugin Invocation ---
echo "=== 🖥️  Live Plugin Invocation ==="

CREATE_OUT=$(herdr workspace create --label "smoke-test-herdr-file-viewer" --focus 2>&1) || {
  fail "could not create a scratch workspace: $CREATE_OUT"
  echo ""
  echo "❌ Smoke test failed."
  exit 1
}
WORKSPACE_ID=$(echo "$CREATE_OUT" | jq -r '.result.workspace.workspace_id')

BEFORE_COUNT=$(herdr pane list --workspace "$WORKSPACE_ID" | jq '.result.panes | length')

if herdr plugin action invoke open-file-viewer --plugin "$PLUGIN_ID" >/dev/null 2>&1; then
  pass "invoked the ${PLUGIN_ID} open-file-viewer action"
else
  fail "failed to invoke the ${PLUGIN_ID} open-file-viewer action"
fi

AFTER_COUNT=$(herdr pane list --workspace "$WORKSPACE_ID" | jq '.result.panes | length')
if [ "$AFTER_COUNT" -gt "$BEFORE_COUNT" ]; then
  pass "file-viewer opened a pane in the scratch workspace ($BEFORE_COUNT -> $AFTER_COUNT panes)"
else
  fail "file-viewer did not open a pane in the scratch workspace ($BEFORE_COUNT -> $AFTER_COUNT panes)"
fi

echo ""

# --- Result ---
if [ "$FAILED" -eq 0 ]; then
  echo "🎉 All smoke tests passed!"
else
  echo "❌ Some smoke tests failed."
  exit 1
fi
