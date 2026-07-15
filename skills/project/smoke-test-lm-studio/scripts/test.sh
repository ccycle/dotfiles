#!/usr/bin/env bash
set -euo pipefail

# --- Configuration ---
HOSTNAME=$(hostname)
FAILED=0

# --- Helpers ---
pass() { echo "✅ $1"; }
fail() { echo "❌ $1"; FAILED=1; }

check_http() {
  local name="$1"
  local url="$2"
  local extra_args="${3:-}"
  if curl -sf --max-time 10 $extra_args "$url" > /dev/null 2>&1; then
    pass "$name ($url)"
  else
    fail "$name ($url)"
  fi
}

# --- 1. LM Studio Server ---
echo "=== 🤖 LM Studio Server ==="

check_http "LM Studio API" "http://127.0.0.1:1234/v1/models"

echo ""

# --- 2. Caddy Reverse Proxy (HTTP) ---
echo "=== 🔗 Caddy Reverse Proxy ==="

check_http "LM Studio via Caddy" "http://llm.${HOSTNAME}.internal/v1/models"

echo ""

# --- Result ---
if [ "$FAILED" -eq 0 ]; then
  echo "🎉 All smoke tests passed!"
else
  echo "❌ Some smoke tests failed."
  exit 1
fi
