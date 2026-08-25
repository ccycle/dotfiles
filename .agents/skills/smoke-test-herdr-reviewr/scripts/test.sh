#!/usr/bin/env bash
set -euo pipefail

# --- Configuration ---
PLUGIN_ID="persiyanov.reviewr"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
HERDR_CFG="$HOME/.config/herdr/config.toml"
REVIEWR_CFG="$HOME/.config/herdr/plugins/config/${PLUGIN_ID}/config.toml"
WORKSPACE_ID=""
FAILED=0

# --- Helpers ---
pass() { echo "✅ $1"; }
fail() {
  echo "❌ $1"
  FAILED=1
}

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

if herdr plugin list --json 2>/dev/null | jq -e --arg id "$PLUGIN_ID" '.result.plugins[] | select(.id == $id)' >/dev/null 2>&1; then
  pass "$PLUGIN_ID is installed"
else
  fail "$PLUGIN_ID is not installed (run: herdr plugin install persiyanov/herdr-reviewr)"
fi

echo ""

# --- 3. Config Symlinks ---
echo "=== 🔗 Config Symlinks ==="

if [ -L "$HERDR_CFG" ] && grep -q "${PLUGIN_ID}.toggle" "$HERDR_CFG"; then
  pass "herdr config.toml is symlinked and defines the reviewr toggle keybinding"
else
  fail "herdr config.toml is missing, not a symlink, or missing the reviewr toggle keybinding"
fi

if [ -L "$REVIEWR_CFG" ] && readlink "$REVIEWR_CFG" | grep -q "modules/herdr/reviewr-config.toml"; then
  pass "reviewr config.toml is symlinked into the repo"
else
  fail "reviewr config.toml is missing or not symlinked into the repo"
fi

echo ""

# --- 4. Live Plugin Invocation ---
echo "=== 🖥️  Live Plugin Invocation ==="

CREATE_OUT=$(herdr workspace create --label "smoke-test-herdr-reviewr" --focus --cwd "$REPO_ROOT" 2>&1) || {
  fail "could not create a scratch workspace: $CREATE_OUT"
  echo ""
  echo "❌ Smoke test failed."
  exit 1
}
WORKSPACE_ID=$(echo "$CREATE_OUT" | jq -r '.result.workspace.workspace_id')

BEFORE_COUNT=$(herdr pane list --workspace "$WORKSPACE_ID" | jq '.result.panes | length')

if herdr plugin action invoke open --plugin "$PLUGIN_ID" >/dev/null 2>&1; then
  pass "invoked the ${PLUGIN_ID} open action"
else
  fail "failed to invoke the ${PLUGIN_ID} open action"
fi

AFTER_COUNT=$(herdr pane list --workspace "$WORKSPACE_ID" | jq '.result.panes | length')
if [ "$AFTER_COUNT" -gt "$BEFORE_COUNT" ]; then
  pass "reviewr opened a pane in the scratch workspace ($BEFORE_COUNT -> $AFTER_COUNT panes)"
else
  fail "reviewr did not open a pane in the scratch workspace ($BEFORE_COUNT -> $AFTER_COUNT panes)"
fi

echo ""

# --- Result ---
if [ "$FAILED" -eq 0 ]; then
  echo "🎉 All smoke tests passed!"
else
  echo "❌ Some smoke tests failed."
  exit 1
fi
