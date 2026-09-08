#!/usr/bin/env bash
# Review and (optionally) apply the Tailscale ACL policy
# (modules/tailscale/policy.hujson) via OpenTofu, replacing the old
# "copy-paste into the admin console" manual step. See
# modules/tailscale/design.md and .agents/skills/tailscale-acl-apply/SKILL.md
# for the full picture, including one-time bootstrap prerequisites.
#
# Usage:
#   scripts/tailscale-acl-apply.sh          # init + fmt/validate + plan only
#   scripts/tailscale-acl-apply.sh --apply   # ...then `tofu apply` (which
#                                             # shows the plan again and
#                                             # requires typing "yes")
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${REPO_ROOT}/modules/tailscale/terraform"
SECRETS_FILE="${REPO_ROOT}/modules/tailscale/secrets.yaml"

die() {
  echo "error: $*" >&2
  exit 1
}

APPLY=false
case "${1:-}" in
--apply)
  APPLY=true
  ;;
"") ;;
-h | --help)
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
  ;;
*)
  die "unknown option: $1 (see --help)"
  ;;
esac

secrets_json="$("${REPO_ROOT}/scripts/sops/sops-with-rbw" -d --output-type json "${SECRETS_FILE}")"
TAILSCALE_OAUTH_CLIENT_ID="$(jq -r '.tailscale_tf_oauth_client_id // empty' <<<"${secrets_json}")"
TAILSCALE_OAUTH_CLIENT_SECRET="$(jq -r '.tailscale_tf_oauth_client_secret // empty' <<<"${secrets_json}")"
TAILSCALE_TAILNET="$(jq -r '.tailscale_tailnet // empty' <<<"${secrets_json}")"
export TAILSCALE_OAUTH_CLIENT_ID TAILSCALE_OAUTH_CLIENT_SECRET TAILSCALE_TAILNET
unset secrets_json

[ -n "${TAILSCALE_OAUTH_CLIENT_ID}" ] || die "tailscale_tf_oauth_client_id missing from ${SECRETS_FILE} (see the tailscale-acl-apply skill's Prerequisites)"
[ -n "${TAILSCALE_OAUTH_CLIENT_SECRET}" ] || die "tailscale_tf_oauth_client_secret missing from ${SECRETS_FILE} (see the tailscale-acl-apply skill's Prerequisites)"
[ -n "${TAILSCALE_TAILNET}" ] || die "tailscale_tailnet missing from ${SECRETS_FILE}"

cd "${TF_DIR}"
tofu init -input=false
tofu fmt -check -diff
tofu validate

if [ "${APPLY}" = true ]; then
  tofu apply
else
  tofu plan
fi
