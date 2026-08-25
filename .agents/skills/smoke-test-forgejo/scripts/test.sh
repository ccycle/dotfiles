#!/usr/bin/env bash
set -euo pipefail

# --- Configuration ---
PROJECT_NAME="forgejo"
HOSTNAME=$(hostname)
FAILED=0

# --- Helpers ---
pass() { echo "✅ $1"; }
fail() {
  echo "❌ $1"
  FAILED=1
}

check_http() {
  local name="$1"
  local url="$2"
  local extra_args="${3:-}"
  if curl -sf --max-time 10 $extra_args "$url" >/dev/null 2>&1; then
    pass "$name ($url)"
  else
    fail "$name ($url)"
  fi
}

# --- 1. Container Status ---
echo "=== 🐳 Container Status ==="

if ! docker compose -p "$PROJECT_NAME" ps --format json >/dev/null 2>&1; then
  fail "Cannot reach Docker Compose project '$PROJECT_NAME'"
  echo ""
  echo "❌ Smoke test failed."
  exit 1
fi

EXPECTED_SERVICES="forgejo"
for svc in $EXPECTED_SERVICES; do
  state=$(docker compose -p "$PROJECT_NAME" ps --format json "$svc" 2>/dev/null | jq -r '.State // empty' 2>/dev/null || true)
  if [ "$state" = "running" ]; then
    pass "$svc is running"
  else
    fail "$svc is not running (state: ${state:-not found})"
  fi
done

echo ""

# --- 2. Health Endpoints ---
echo "=== 🏥 Health Endpoints ==="

check_http "Forgejo" "http://127.0.0.1:3000/api/healthz"

echo ""

# --- 3. Caddy Reverse Proxy (HTTPS) ---
echo "=== 🔒 Caddy Reverse Proxy ==="

check_http "Forgejo (HTTPS)" "https://forgejo.${HOSTNAME}.internal" "--insecure"

echo ""

# --- Result ---
if [ "$FAILED" -eq 0 ]; then
  echo "🎉 All smoke tests passed!"
else
  echo "❌ Some smoke tests failed."
  exit 1
fi
