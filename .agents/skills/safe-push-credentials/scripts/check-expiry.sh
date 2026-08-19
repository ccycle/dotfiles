#!/usr/bin/env bash
set -euo pipefail

THRESHOLD_DAYS="${1:-14}"
TOKEN_FILE="${TOKEN_FILE:-/run/secrets/github-agent-push-token}"

if [ ! -r "$TOKEN_FILE" ]; then
  echo "check-expiry: token file not readable: $TOKEN_FILE" >&2
  echo "Override with TOKEN_FILE=<path> if sops-nix deploys it elsewhere." >&2
  exit 2
fi

headers=$(curl -sS -D - -o /dev/null \
  -H "Authorization: Bearer $(cat "$TOKEN_FILE")" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/rate_limit)

expiry_line=$(printf '%s' "$headers" | tr -d '\r' | grep -i '^github-authentication-token-expiration:' || true)

if [ -z "$expiry_line" ]; then
  echo "check-expiry: no expiration header in the API response." >&2
  echo "Either the token is invalid/revoked, or GitHub changed the header name." >&2
  printf '%s\n' "$headers" | head -1 >&2
  exit 2
fi

expiry_date=${expiry_line#*: }
expiry_epoch=$(date -j -f "%Y-%m-%d %H:%M:%S %z" "$expiry_date" +%s)
now_epoch=$(date +%s)
days_left=$(((expiry_epoch - now_epoch) / 86400))

echo "git-safe-push token expires: $expiry_date ($days_left days left)"

if [ "$days_left" -le "$THRESHOLD_DAYS" ]; then
  echo "WARNING: expires within $THRESHOLD_DAYS days. Rotate with rotate-token.sh." >&2
  exit 1
fi

exit 0
