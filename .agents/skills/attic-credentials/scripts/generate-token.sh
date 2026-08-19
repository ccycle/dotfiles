#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 ci"
  echo "       $0 smoke"
  echo "       $0 client <machine>"
  exit 1
fi

ROLE="$1"
ATTIC_HOST="${ATTIC_HOST:-mac-mini-m4-pro}"
SECRETS_FILE="modules/attic/secrets.yaml"
CACHE_NAME="dotfiles"
JWT_SECRET_PATH="/run/secrets/atticd-jwt-secret"

case "$ROLE" in
  ci)
    SUB="ci"
    SOP_KEY="attic-ci-token"
    ;;
  smoke)
    SUB="smoke"
    SOP_KEY="attic-smoke-token"
    ;;
  client)
    MACHINE="${2:-}"
    if [ -z "$MACHINE" ]; then
      echo "Error: 'client' role requires a machine name: $0 client <machine>"
      exit 1
    fi
    SUB="$MACHINE"
    SOP_KEY="attic-client-${MACHINE}-token"
    ;;
  *)
    echo "Unknown role: $ROLE (expected: ci, smoke, client)"
    exit 1
    ;;
esac

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

echo "Generating token for role '$ROLE' (sub: $SUB, push: $CACHE_NAME, validity: 10 years)..."
# atticadm runs on the server itself and needs the JWT signing secret in its
# environment (see modules/attic/options.nix's launchd script). Reading it
# requires root, hence the sudo.
TOKEN=$(run_on_attic_host \
  "export ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64=\"\$(sudo cat $JWT_SECRET_PATH)\" && atticadm -f /etc/atticd/server.toml make-token --sub '$SUB' --push '$CACHE_NAME' --validity 10y")

sops --set '["'"$SOP_KEY"'"] "'"$TOKEN"'"' "$SECRETS_FILE"
echo "Token encrypted to $SECRETS_FILE (key: $SOP_KEY)"

case "$ROLE" in
  ci)
    echo ""
    echo "=== CI Token — paste into Forgejo Settings -> Actions -> Secrets (ATTIC_CI_TOKEN) ==="
    echo "$TOKEN"
    echo "======================================================================================"
    ;;
  smoke)
    echo ""
    echo "smoke-test-attic reads this via the sops secret deployed by modules/attic/home.nix"
    echo "(~/.config/sops-nix/secrets/attic-smoke-token) — no manual copy needed."
    ;;
  client)
    echo ""
    echo "=== Client Token — on $MACHINE, run once: ==="
    echo "attic login $ATTIC_HOST https://cache.${ATTIC_HOST}.internal $TOKEN --set-default"
    echo "==============================================="
    ;;
esac
