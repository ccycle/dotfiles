#!/usr/bin/env bash
set -euo pipefail

# --- Configuration ---
PROJECT_NAME="monitoring"
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

# --- 1. Container Status ---
echo "=== 🐳 Container Status ==="

if ! docker compose -p "$PROJECT_NAME" ps --format json > /dev/null 2>&1; then
  fail "Cannot reach Docker Compose project '$PROJECT_NAME'"
  echo ""
  echo "❌ Smoke test failed."
  exit 1
fi

EXPECTED_SERVICES="prometheus grafana loki alloy cadvisor"
for svc in $EXPECTED_SERVICES; do
  state=$(docker compose -p "$PROJECT_NAME" ps --format json "$svc" 2>/dev/null | jq -r '.State // empty' 2>/dev/null || true)
  if [ "$state" = "running" ]; then
    pass "$svc is running"
  else
    fail "$svc is not running (state: ${state:-not found})"
  fi
done

echo ""

# --- 2. Health Endpoints (localhost) ---
echo "=== 🏥 Health Endpoints ==="

check_http "Prometheus" "http://127.0.0.1:9090/-/healthy"
check_http "Grafana"    "http://127.0.0.1:3000/api/health"
check_http "Loki"       "http://127.0.0.1:3100/ready"
check_http "cAdvisor"   "http://127.0.0.1:8081/healthz"

echo ""

# --- 3. Caddy Reverse Proxy (HTTPS) ---
echo "=== 🔒 Caddy Reverse Proxy ==="

check_http "Grafana (HTTPS)"    "https://grafana.${HOSTNAME}.internal" "--insecure"
check_http "Prometheus (HTTPS)" "https://prometheus.${HOSTNAME}.internal" "--insecure"

echo ""

# --- 4. Prometheus Scrape Targets ---
echo "=== 🎯 Prometheus Scrape Targets ==="

EXPECTED_JOBS="prometheus cadvisor immich-api immich-microservices gitlab-rails gitlab-sidekiq gitlab-postgres gitlab-redis gitlab-exporter-sidekiq"
targets_json=$(curl -sf --max-time 10 "http://127.0.0.1:9090/api/v1/targets" || true)
if [ -z "$targets_json" ]; then
  fail "Cannot fetch Prometheus targets API"
else
  for job in $EXPECTED_JOBS; do
    health=$(echo "$targets_json" | jq -r --arg j "$job" '[.data.activeTargets[] | select(.labels.job == $j) | .health] | first // empty')
    if [ "$health" = "up" ]; then
      pass "target '$job' is up"
    else
      fail "target '$job' is not up (health: ${health:-missing})"
    fi
  done
fi

echo ""

# --- 5. Provisioned Grafana Dashboards ---
echo "=== 📊 Provisioned Dashboards ==="

EXPECTED_DASHBOARDS="services-overview gitlab-health logs-explorer"
for uid in $EXPECTED_DASHBOARDS; do
  if docker compose -p "$PROJECT_NAME" exec -T grafana \
    test -f "/var/lib/grafana/dashboards/${uid}.json" > /dev/null 2>&1; then
    pass "dashboard '$uid' is provisioned"
  else
    fail "dashboard '$uid' is missing from /var/lib/grafana/dashboards"
  fi
done

echo ""

# --- Result ---
if [ "$FAILED" -eq 0 ]; then
  echo "🎉 All smoke tests passed!"
else
  echo "❌ Some smoke tests failed."
  exit 1
fi
