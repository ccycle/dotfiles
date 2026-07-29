#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <role>"
  echo "Roles: watch-store, ci"
  exit 1
fi

ROLE="$1"
ATTIC_HOST="${ATTIC_HOST:-mac-mini-m4-pro}"
SECRETS_FILE="modules/attic/secrets.yaml"
CACHE_NAME="dotfiles"

cd "$(git rev-parse --show-toplevel)"

echo "Generating token for role '$ROLE' (validity: 10 years)..."
TOKEN=$(ssh "$ATTIC_HOST" -- attic token create -c "$CACHE_NAME" "$ROLE" --validity "10y" | head -1)

SOP_KEY="attic-${ROLE}-token"
sops --set '["'"$SOP_KEY"'"] "'"$TOKEN"'"' "$SECRETS_FILE"
echo "Token encrypted to $SECRETS_FILE (key: $SOP_KEY)"

if [ "$ROLE" = "ci" ]; then
  echo ""
  echo "=== New CI Token — paste into Forgejo Secrets (ATTIC_CI_TOKEN) ==="
  echo "$TOKEN"
  echo "================================================================"
fi

echo ""
echo "Done."
exit 0
