#!/usr/bin/env bash
set -euo pipefail

ATTIC_HOST="${ATTIC_HOST:-mac-mini-m4-pro}"
SECRETS_FILE="modules/attic/secrets.yaml"
CACHE_NAME="dotfiles"

cd "$(git rev-parse --show-toplevel)"

# --- Step 1: JWT secret ---
echo "=== Step 1: JWT secret ==="
if sops --decrypt "$SECRETS_FILE" 2>/dev/null | grep -q "^atticd-jwt-secret:"; then
  echo "JWT secret already exists in $SECRETS_FILE, skipping."
else
  echo "Generating JWT secret..."
  JWT_SECRET=$(openssl rand -base64 32)
  sops --set '["atticd-jwt-secret"] "'"$JWT_SECRET"'"' "$SECRETS_FILE"
  echo "JWT secret encrypted to $SECRETS_FILE"
fi

# --- Step 2: Deploy atticd ---
echo ""
echo "=== Step 2: Deploy atticd on $ATTIC_HOST ==="
ssh "$ATTIC_HOST" -- darwin-rebuild switch --flake . 2>&1 || {
  echo "Warning: darwin-rebuild failed. Ensure atticd is running manually."
}

# --- Step 3: Create cache ---
echo ""
echo "=== Step 3: Create cache '$CACHE_NAME' on $ATTIC_HOST ==="
CACHE_EXISTS=$(ssh "$ATTIC_HOST" -- attic cache list 2>/dev/null | grep -c "$CACHE_NAME" || true)
if [ "$CACHE_EXISTS" -eq 0 ]; then
  ssh "$ATTIC_HOST" -- attic cache create "$CACHE_NAME"
  echo "Cache '$CACHE_NAME' created."
else
  echo "Cache '$CACHE_NAME' already exists, skipping."
fi

# --- Step 4: Show public key ---
echo ""
echo "=== Step 4: Public key (paste into bootstrap/modules/attic/darwin.nix) ==="
ssh "$ATTIC_HOST" -- attic cache info "$CACHE_NAME"

# --- Step 5: Watch-store token ---
echo ""
echo "=== Step 5: Generate watch-store token ==="
SKIP_WATCH=false
if sops --decrypt "$SECRETS_FILE" 2>/dev/null | grep -q "^attic-watch-token:"; then
  echo "attic-watch-token already exists. Overwrite? [y/N]"
  read -r response
  if [ "$response" != "y" ]; then
    echo "Skipping watch-store token."
    SKIP_WATCH=true
  fi
fi

if [ "$SKIP_WATCH" = false ]; then
  WATCH_TOKEN=$(ssh "$ATTIC_HOST" -- attic token create -c "$CACHE_NAME" watch-store --validity "10y" | head -1)
  sops --set '["attic-watch-token"] "'"$WATCH_TOKEN"'"' "$SECRETS_FILE"
  echo "watch-store token encrypted to $SECRETS_FILE"
fi

# --- Step 6: CI token ---
echo ""
echo "=== Step 6: Generate CI token ==="
SKIP_CI=false
if sops --decrypt "$SECRETS_FILE" 2>/dev/null | grep -q "^attic-ci-token:"; then
  echo "attic-ci-token already exists. Overwrite? [y/N]"
  read -r response
  if [ "$response" != "y" ]; then
    echo "Skipping CI token."
    SKIP_CI=true
  fi
fi

if [ "$SKIP_CI" = false ]; then
  CI_TOKEN=$(ssh "$ATTIC_HOST" -- attic token create -c "$CACHE_NAME" ci --validity "10y" | head -1)
  sops --set '["attic-ci-token"] "'"$CI_TOKEN"'"' "$SECRETS_FILE"
  echo ""
  echo "=== CI Token (plaintext) — paste into Forgejo Secrets as ATTIC_CI_TOKEN ==="
  echo "$CI_TOKEN"
  echo "====================================================================="
fi

echo ""
echo "=== Done ==="
echo "Next steps:"
echo "  1. Paste the public key from Step 4 into bootstrap/modules/attic/darwin.nix"
echo "  2. Paste the CI token into Forgejo Settings → Actions → Secrets"
exit 0
