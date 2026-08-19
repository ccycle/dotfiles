#!/usr/bin/env bash
set -euo pipefail

# --- Configuration ---
HOSTNAME=$(hostname)
PORT=8880
FAILED=0

# --- Helpers ---
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAILED=1; }

check_http() {
  local name="$1"
  local url="$2"
  if curl -sf --max-time 10 "$url" > /dev/null 2>&1; then
    pass "$name ($url)"
  else
    fail "$name ($url)"
  fi
}

# --- 1. llama-swap Health ---
echo "=== llama-swap Health ==="

check_http "llama-swap health" "http://127.0.0.1:${PORT}/health"

echo ""

# --- 2. llama-swap Models ---
echo "=== llama-swap Models ==="

check_http "llama-swap models" "http://127.0.0.1:${PORT}/v1/models"

echo ""

# --- 3. Caddy Reverse Proxy (HTTP) ---
echo "=== Caddy Reverse Proxy ==="

check_http "LLM via Caddy" "http://llm.${HOSTNAME}.internal/v1/models"

echo ""

# --- Result ---
if [ "$FAILED" -eq 0 ]; then
  echo "All smoke tests passed!"
else
  echo "Some smoke tests failed."
  exit 1
fi
