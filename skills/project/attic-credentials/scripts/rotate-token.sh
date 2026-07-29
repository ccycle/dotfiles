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

SOP_KEY="attic-${ROLE}-token"

# --- Step 1: Show current tokens for reference ---
echo "Current tokens on $ATTIC_HOST for cache '$CACHE_NAME':"
ssh "$ATTIC_HOST" -- attic token list --cache "$CACHE_NAME" 2>/dev/null || \
  ssh "$ATTIC_HOST" -- attic token list 2>/dev/null || \
  echo "(Unable to list tokens. Continuing anyway.)"

echo ""

# --- Step 2: Generate new token ---
echo "Generating new token for role '$ROLE' (validity: 10 years)..."
NEW_TOKEN=$(ssh "$ATTIC_HOST" -- attic token create -c "$CACHE_NAME" "$ROLE" --validity "10y" | head -1)

# --- Step 3: Update sops ---
sops --set '["'"$SOP_KEY"'"] "'"$NEW_TOKEN"'"' "$SECRETS_FILE"
echo "New token encrypted to $SECRETS_FILE (key: $SOP_KEY)"

if [ "$ROLE" = "ci" ]; then
  echo ""
  echo "=== New CI Token — update Forgejo Secrets (ATTIC_CI_TOKEN) ==="
  echo "$NEW_TOKEN"
  echo "=============================================================="
fi

# --- Step 4: Manual revoke instructions ---
echo ""
echo "=== Manual revocation required ==="
echo "The old token has not been revoked automatically."
echo "To revoke old tokens, run on $ATTIC_HOST:"
echo "  attic token revoke <hash>"
echo ""
echo "Find the old token hashes from the list above."
echo "Tokens that match role '$ROLE' are the ones to revoke."
echo "The new token is already in use (sops-encrypted), so old ones can"
echo "be safely revoked after verifying the new token works."
echo "================================"

exit 0
