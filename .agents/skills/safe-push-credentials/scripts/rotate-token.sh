#!/usr/bin/env bash
set -euo pipefail

SECRETS_FILE="modules/git/github/safe-push/secrets.yaml"
SOP_KEY="github-agent-push-token"

cd "$(git rev-parse --show-toplevel)"

echo "=== Rotate the git-safe-push fine-grained PAT ==="
echo ""
echo "Fine-grained PATs cannot be created headlessly; generate the new one"
echo "in the browser first:"
echo "  1. https://github.com/settings/personal-access-tokens/new"
echo "  2. Resource owner: the repo's owner. Repository access: 'Only select"
echo "     repositories' -> this repo only."
echo "  3. Permissions: Contents = Read and write. Nothing else."
echo "  4. Set an expiration (do not choose 'No expiration')."
echo ""
echo "Paste the new token below (input is not echoed) and press enter:"
read -rs NEW_TOKEN
echo ""

if [ -z "$NEW_TOKEN" ]; then
  echo "rotate-token: empty token, aborting." >&2
  exit 1
fi

sops --set '["'"$SOP_KEY"'"] "'"$NEW_TOKEN"'"' "$SECRETS_FILE"
echo "New token encrypted to $SECRETS_FILE (key: $SOP_KEY)."
echo ""
echo "Next steps:"
echo "  1. Rebuild so the new secret is deployed (darwin-rebuild switch or"
echo "     the /darwin-rebuild skill)."
echo "  2. Verify: .agents/skills/safe-push-credentials/scripts/check-expiry.sh"
echo "  3. Revoke the OLD token at:"
echo "     https://github.com/settings/personal-access-tokens"
echo "     (find the previous git-safe-push token and revoke it manually —"
echo "     this script does not know its identity, only its replacement)."
