#!/usr/bin/env bash
set -euo pipefail

# --- Configuration ---
PROJECT_NAME="opencloud"
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

EXPECTED_SERVICES="opencloud"
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

check_http "OpenCloud" "http://127.0.0.1:9200/health"

echo ""

# --- 3. Caddy Reverse Proxy (HTTPS) ---
echo "=== 🔒 Caddy Reverse Proxy ==="

check_http "OpenCloud (HTTPS)" "https://opencloud.${HOSTNAME}.internal" "--insecure"

echo ""

# --- 4. Directory Structure (PosixFS layout) ---
echo "=== 📁 PosixFS Directory Structure ==="

container="${PROJECT_NAME}-opencloud-1"
if docker inspect "$container" > /dev/null 2>&1; then
  # Get host-side bind mount paths
  data_host=$(docker inspect "$container" --format '{{range .Mounts}}{{if eq .Destination "/var/lib/opencloud"}}{{.Source}}{{end}}{{end}}')
  userfiles_host=$(docker inspect "$container" --format '{{range .Mounts}}{{if eq .Destination "/host/user-files"}}{{.Source}}{{end}}{{end}}')

  if [ -n "$data_host" ] && [ -d "$data_host" ]; then
    pass "data dir exists at $data_host"
  else
    fail "data dir not found at $data_host"
  fi

  if [ -n "$userfiles_host" ] && [ -d "$userfiles_host" ]; then
    pass "user-files dir exists at $userfiles_host"
  else
    fail "user-files dir not found or not mounted"
  fi

  # Verify they are separate directories
  if [ -n "$data_host" ] && [ -n "$userfiles_host" ] && [ "$data_host" != "$userfiles_host" ]; then
    pass "user-files and data are separate directories"
  elif [ -n "$data_host" ] && [ -n "$userfiles_host" ]; then
    fail "user-files and data are the SAME directory"
  fi

  # Verify STORAGE_USERS_POSIX_ROOT inside the container
  if docker exec "$container" stat /host/user-files > /dev/null 2>&1; then
    pass "STORAGE_USERS_POSIX_ROOT (/host/user-files) is accessible inside container"
  else
    fail "STORAGE_USERS_POSIX_ROOT (/host/user-files) not accessible inside container"
  fi
else
  fail "Container $container not found — cannot inspect directory structure"
fi

echo ""

# --- 5. Bundled Web Apps ---
echo "=== 📦 Bundled Web Apps ==="

# External apps mount is read-only into the container's apps directory.
apps_mount=$(docker inspect "$container" --format '{{range .Mounts}}{{if eq .Destination "/var/lib/opencloud/web/assets/apps"}}{{.Source}}{{end}}{{end}}' 2>/dev/null)
if [ -n "$apps_mount" ] && docker exec "$container" ls /var/lib/opencloud/web/assets/apps > /dev/null 2>&1; then
  for appdir in $(docker exec "$container" sh -c "ls /var/lib/opencloud/web/assets/apps" 2>/dev/null); do
    if docker exec "$container" sh -c "[ -f /var/lib/opencloud/web/assets/apps/$appdir/manifest.json ]" 2>/dev/null; then
      pass "web app '$appdir' has manifest.json"
      # The web service must have registered it in /config.json external_apps
      if curl -sf --max-time 10 "http://127.0.0.1:9200/config.json" 2>/dev/null | jq -e --arg id "$appdir" '.external_apps[] | select(.id == $id)' > /dev/null 2>&1; then
        pass "web app '$appdir' registered in web config"
      else
        fail "web app '$appdir' NOT registered in web config (restart opencloud-compose)"
      fi
    else
      fail "web app dir '$appdir' has no manifest.json"
    fi
  done
else
  fail "No apps mount at /var/lib/opencloud/web/assets/apps"
fi

echo ""

# --- Result ---
if [ "$FAILED" -eq 0 ]; then
  echo "🎉 All smoke tests passed!"
else
  echo "❌ Some smoke tests failed."
  exit 1
fi
