#!/usr/bin/env bash
set -euo pipefail

# --- Configuration ---
ATTIC_HOST="${ATTIC_HOST:-mac-mini-m4-pro}"
CACHE_NAME="dotfiles"
CADDY_URL="https://cache.${ATTIC_HOST}.internal"
TOKEN_FILE="${TOKEN_FILE:-$HOME/.config/sops-nix/secrets/attic-smoke-token}"
NIX_CA_BUNDLE="/etc/nix/ca-bundle.crt"
FAILED=0

# --- Helpers ---
pass() { echo "✅ $1"; }
fail() { echo "❌ $1"; FAILED=1; }

check_http() {
  local name="$1"
  local url="$2"
  local extra_args="${3:-}"
  local code
  code=$(curl -s --max-time 10 $extra_args -o /dev/null -w '%{http_code}' "$url" 2>/dev/null || echo "000")
  if [ "$code" = "200" ]; then
    pass "$name ($url) -> $code"
  else
    fail "$name ($url) -> $code"
  fi
}

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

# --- 1. Pre-flight: Caddy/atticd reachability ---
# Public read endpoint, no token required — isolates "is the server up"
# from "does my push token/TLS trust work" before attempting the round-trip.
echo "=== 🌐 Pre-flight: Caddy reachability ==="

check_http "nix-cache-info (-k)" "$CADDY_URL/$CACHE_NAME/nix-cache-info" "--insecure"
if [ -f "$NIX_CA_BUNDLE" ]; then
  check_http "nix-cache-info (CA bundle)" "$CADDY_URL/$CACHE_NAME/nix-cache-info" "--cacert $NIX_CA_BUNDLE"
else
  fail "nix-cache-info (CA bundle) -- $NIX_CA_BUNDLE not found on this host"
fi

echo ""

if [ "$FAILED" -ne 0 ]; then
  echo "❌ Pre-flight failed; skipping push→read round-trip."
  exit 1
fi

# --- 2. Push→read round-trip ---
echo "=== 🔄 Push→read round-trip (via $CADDY_URL) ==="

if [ ! -r "$TOKEN_FILE" ]; then
  fail "smoke token not found at $TOKEN_FILE (run: skills/project/attic-credentials/scripts/generate-token.sh smoke)"
  echo ""
  echo "❌ Smoke test failed."
  exit 1
fi

# Ephemeral attic client config, isolated via XDG_CONFIG_HOME so this never
# touches a host's real ~/.config/attic/config.toml.
CONFIG_HOME="$WORKDIR/xdg-config"
mkdir -p "$CONFIG_HOME/attic"
cat > "$CONFIG_HOME/attic/config.toml" <<EOF
default-server = "smoke"

[servers.smoke]
endpoint = "$CADDY_URL"
token-file = "$TOKEN_FILE"
EOF
chmod 600 "$CONFIG_HOME/attic/config.toml"

# Fresh, unique payload each run so `attic push` can't short-circuit on an
# already-cached path.
PAYLOAD_FILE="$WORKDIR/payload"
printf 'attic smoke test %s %s\n' "$(date +%s)" "$RANDOM" > "$PAYLOAD_FILE"
STORE_PATH=$(nix-store --add "$PAYLOAD_FILE")

PUSH_OUTPUT=$(XDG_CONFIG_HOME="$CONFIG_HOME" attic push --no-closure smoke:"$CACHE_NAME" "$STORE_PATH" 2>&1) && PUSH_OK=1 || PUSH_OK=0
if [ "$PUSH_OK" -eq 1 ]; then
  pass "attic push $STORE_PATH"
else
  fail "attic push $STORE_PATH"
  echo "$PUSH_OUTPUT"
  if echo "$PUSH_OUTPUT" | grep -qi "certificate\|UnknownIssuer\|invalid peer certificate\|self.signed"; then
    echo ""
    echo "Hint: the attic client validates TLS against this Mac's System keychain,"
    echo "not /etc/nix/ca-bundle.crt. Trust the Caddy CA once with:"
    echo "  sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain /etc/nix/attic-ca.crt"
  fi
  echo ""
  echo "❌ Smoke test failed."
  exit 1
fi

STORE_BASENAME=$(basename "$STORE_PATH")
HASH="${STORE_BASENAME%%-*}"

echo ""
echo "=== 📄 narinfo verification ==="

NARINFO_FILE="$WORKDIR/narinfo"
for variant in "-k" "--cacert $NIX_CA_BUNDLE"; do
  [ "$variant" = "--cacert $NIX_CA_BUNDLE" ] && [ ! -f "$NIX_CA_BUNDLE" ] && continue
  CODE=$(curl -s --max-time 10 $variant -o "$NARINFO_FILE" -w '%{http_code}' "$CADDY_URL/$CACHE_NAME/$HASH.narinfo" 2>/dev/null || echo "000")
  if [ "$CODE" = "200" ]; then
    pass "narinfo fetch ($variant) -> $CODE"
  else
    fail "narinfo fetch ($variant) -> $CODE"
  fi
done

if [ ! -s "$NARINFO_FILE" ]; then
  fail "narinfo response is empty; cannot verify StorePath/NAR"
  echo ""
  echo "❌ Smoke test failed."
  exit 1
fi

NARINFO_STORE_PATH=$(awk '/^StorePath:/ {print $2}' "$NARINFO_FILE")
if [ "$NARINFO_STORE_PATH" = "$STORE_PATH" ]; then
  pass "narinfo StorePath matches ($STORE_PATH)"
else
  fail "narinfo StorePath mismatch: expected $STORE_PATH, got $NARINFO_STORE_PATH"
fi

NAR_URL_REL=$(awk '/^URL:/ {print $2}' "$NARINFO_FILE")
NAR_HASH=$(awk '/^NarHash:/ {print $2}' "$NARINFO_FILE")
NAR_HASH="${NAR_HASH#sha256:}"

echo ""
echo "=== 📦 NAR integrity ==="

NAR_FILE="$WORKDIR/nar.zst"
CODE=$(curl -s --max-time 15 --cacert "$NIX_CA_BUNDLE" -o "$NAR_FILE" -w '%{http_code}' "$CADDY_URL/$CACHE_NAME/$NAR_URL_REL" 2>/dev/null || echo "000")
if [ "$CODE" = "200" ]; then
  pass "NAR fetch ($NAR_URL_REL) -> $CODE"
else
  fail "NAR fetch ($NAR_URL_REL) -> $CODE"
fi

DOWNLOADED_SHA256=$(zstd -dc "$NAR_FILE" 2>/dev/null | sha256sum | awk '{print $1}')
LOCAL_SHA256=$(nix-store --dump "$STORE_PATH" | sha256sum | awk '{print $1}')

if [ "$DOWNLOADED_SHA256" = "$NAR_HASH" ] && [ "$LOCAL_SHA256" = "$NAR_HASH" ]; then
  pass "NAR sha256 matches narinfo NarHash and local nix-store --dump ($NAR_HASH)"
else
  fail "NAR sha256 mismatch: narinfo=$NAR_HASH downloaded=$DOWNLOADED_SHA256 local=$LOCAL_SHA256"
fi

echo ""

# --- Result ---
if [ "$FAILED" -eq 0 ]; then
  echo "🎉 All smoke tests passed!"
else
  echo "❌ Some smoke tests failed."
  exit 1
fi
