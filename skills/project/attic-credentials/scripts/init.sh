#!/usr/bin/env bash
set -euo pipefail

ATTIC_HOST="${ATTIC_HOST:-mac-mini-m4-pro}"
SECRETS_FILE="modules/attic/secrets.yaml"
CACHE_NAME="dotfiles"

cd "$(git rev-parse --show-toplevel)"

# When run on the atticd host itself, skip ssh: self-ssh isn't guaranteed to
# work (no authorized_keys entry for one's own key), and it's unnecessary.
on_attic_host() {
  local h
  h="$(hostname -s 2>/dev/null || hostname)"
  [ "$ATTIC_HOST" = "$h" ] || [ "$ATTIC_HOST" = "$(hostname)" ]
}

run_on_attic_host() {
  if on_attic_host; then
    bash -c "$1"
  else
    ssh "$ATTIC_HOST" -- "$1"
  fi
}

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
run_on_attic_host "darwin-rebuild switch --flake ." 2>&1 || {
  echo "Warning: darwin-rebuild failed. Ensure atticd is running manually."
}

# --- Step 3: Create cache ---
echo ""
echo "=== Step 3: Create cache '$CACHE_NAME' on $ATTIC_HOST ==="
CACHE_EXISTS=$(run_on_attic_host "attic cache list" 2>/dev/null | grep -c "$CACHE_NAME" || true)
if [ "$CACHE_EXISTS" -eq 0 ]; then
  run_on_attic_host "attic cache create $CACHE_NAME"
  echo "Cache '$CACHE_NAME' created."
else
  echo "Cache '$CACHE_NAME' already exists, skipping."
fi

# --- Step 4: Show public key ---
echo ""
echo "=== Step 4: Public key (paste into bootstrap/modules/attic/darwin.nix) ==="
run_on_attic_host "attic cache info $CACHE_NAME"

# --- Step 5: CI token ---
echo ""
echo "=== Step 5: Generate CI token ==="
if sops --decrypt "$SECRETS_FILE" 2>/dev/null | grep -q "^attic-ci-token:"; then
  echo "attic-ci-token already exists. Overwrite? [y/N]"
  read -r response
  if [ "$response" != "y" ]; then
    echo "Skipping CI token."
    response=""
  fi
else
  response="y"
fi

if [ "${response:-}" = "y" ]; then
  "$(dirname "$0")/generate-token.sh" ci
fi

echo ""
echo "=== Done ==="
echo "Next: for each client machine that should push, run"
echo "  ${0%/*}/generate-token.sh client <machine>"
echo "and follow the printed 'attic login' instructions on that machine."

