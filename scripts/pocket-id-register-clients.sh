#!/usr/bin/env bash
# Idempotently reconcile the OIDC clients and user groups declared in
# modules/pocket-id/options.nix (services.pocket-id.oidcClients /
# oidcGroups) against the live Pocket ID admin API on the current host.
#
# Usage:
#   scripts/pocket-id-register-clients.sh [--admin-user <username>] [--dry-run]
#
# Must be run on a target host (mac-mini-m4 or mac-mini-m4-pro) from a
# checkout of the dotfiles repo, by a user who holds that host's sops age
# key. The Pocket ID container listens on 127.0.0.1:1411 (see
# modules/pocket-id/compose.yaml); override with POCKET_ID_API_URL if the
# port has been changed.
#
# One-time manual prerequisite: create a Pocket ID admin API key (UI:
# Settings -> API Keys) and store it as `pocket_id_admin_api_key` in
# modules/pocket-id/secrets-<host>.yaml:
#   sops set modules/pocket-id/secrets-<host>.yaml '["pocket_id_admin_api_key"]' '"<key>"'
#
# Behaviour (the declared config is the single source of truth):
#   - missing clients are created, existing ones updated to match, and a
#     confidential client whose sops secret is missing or still a
#     CHANGE_ME_* placeholder is recreated with a fresh secret
#   - new/recreated confidential client secrets are captured back into sops
#     (POST /api/oidc/clients/{id}/secret returns plaintext; creation does not)
#   - groups and group custom claims (e.g. opencloud_role) are ensured
#   - with --admin-user, that user is added to every group flagged
#     adminGroup in the config
#   - stale *_oidc_client_id keys left in sops by the manual-registration
#     era are removed (each host's own files)
#
# --dry-run reports the plan and may run without an admin API key (it then
# cannot tell existing clients/groups from missing ones, so every object is
# reported as "reconcile" and the diff is best-effort).
#
# Writes only inside the current checkout (sops files); Pocket ID mutations
# are scoped to the clients/groups/users this script owns.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

NIX="nix --extra-experimental-features nix-command --extra-experimental-features flakes"

ADMIN_USER=""
DRY_RUN=false

usage() {
  cat <<'EOF'
Usage: pocket-id-register-clients.sh [--admin-user <username>] [--dry-run]

Reconciles services.pocket-id.oidcClients / oidcGroups (declared in
modules/pocket-id/options.nix) against the live Pocket ID admin API.

  --admin-user <username>  Add this Pocket ID user to every group marked
                           adminGroup in the config (creating the user if
                           it does not exist).
  --dry-run                Report planned actions without changing anything;
                           needs no admin API key.
EOF
}

die() {
  echo "error: $*" >&2
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --admin-user)
      ADMIN_USER="${2:-}"
      [ -n "${ADMIN_USER}" ] || die "--admin-user requires an argument"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1 (see --help)"
      ;;
  esac
done

HOST="$(hostname -s)"
case "${HOST}" in
  mac-mini-m4|mac-mini-m4-pro) ;;
  *) die "unsupported host '${HOST}'; run this on mac-mini-m4 or mac-mini-m4-pro" ;;
esac

# Worktrees lack the gitignored .local/ state; restore it and wire the
# same flake overrides darwin-rebuild.sh uses so nix eval can succeed.
"${REPO_ROOT}/scripts/ensure-local.sh"

eval_args=()
for m in storage obsidian-vault; do
  [ -d "${REPO_ROOT}/.local/${m}" ] && eval_args+=(--override-input "${m}-config" "path:${REPO_ROOT}/.local/${m}")
done
[ -d "${REPO_ROOT}/.local/dotfiles" ] && eval_args+=(--override-input dotfiles-config "path:${REPO_ROOT}/.local/dotfiles")

echo "== reading declared config for ${HOST} =="
clients_json="$(${NIX} eval --json --impure "${eval_args[@]}" ".#darwinConfigurations.${HOST}.config.services.pocket-id.oidcClients")"
groups_json="$(${NIX} eval --json --impure "${eval_args[@]}" ".#darwinConfigurations.${HOST}.config.services.pocket-id.oidcGroups")"

secrets_file="modules/pocket-id/secrets-${HOST}.yaml"
api_key="$(sops -d --output-type json "${secrets_file}" 2>/dev/null | jq -r '.pocket_id_admin_api_key // empty' 2>/dev/null || true)"
HAS_KEY=false
[ -n "${api_key}" ] && HAS_KEY=true

if [ "${DRY_RUN}" = false ] && [ "${HAS_KEY}" = false ]; then
  die "no admin API key in ${secrets_file} (key 'pocket_id_admin_api_key')." \
    "Create one in Pocket ID Settings -> API Keys, then:" \
    "  sops set ${secrets_file} '[\"pocket_id_admin_api_key\"]' '\"<key>\"'"
fi

API_BASE="${POCKET_ID_API_URL:-http://127.0.0.1:1411}"

api() { # method path [json-body] -> response body on stdout
  local method="$1" path="$2" body="${3:-}"
  local args=(-fsS -X "${method}" -H "X-API-KEY: ${api_key}" -H 'Content-Type: application/json')
  if [ -n "${body}" ]; then
    curl "${args[@]}" --data "${body}" "${API_BASE}${path}"
  else
    curl "${args[@]}" "${API_BASE}${path}"
  fi
}

api_code() { # method path [json-body] -> HTTP status code only
  local method="$1" path="$2" body="${3:-}"
  local args=(-s -o /dev/null -w '%{http_code}' -X "${method}" -H "X-API-KEY: ${api_key}" -H 'Content-Type: application/json')
  if [ -n "${body}" ]; then
    curl "${args[@]}" --data "${body}" "${API_BASE}${path}"
  else
    curl "${args[@]}" "${API_BASE}${path}"
  fi
}

if [ "${HAS_KEY}" = true ]; then
  [ "$(api_code GET /healthz)" = "200" ] \
    || die "Pocket ID not reachable at ${API_BASE} (healthz failed). Is pocket-id running?"
elif [ "${DRY_RUN}" = true ]; then
  echo "  (dry-run without admin API key: live client/group state is not checked)"
fi

urlenc() { jq -rn --arg v "$1" '$v | @uri'; }

# --- user groups ---------------------------------------------------------
declare -A GROUP_IDS   # group name -> pocket-id group id (synthetic in dry-run)
declare -A ADMIN_GROUP_IDS  # adminGroup=true group names -> id

echo "== reconciling user groups =="
while IFS= read -r g; do
  name="$(jq -r '.name' <<<"${g}")"
  friendly="$(jq -r '.friendlyName // .name' <<<"${g}")"
  claims="$(jq -c '.customClaims' <<<"${g}")"
  is_admin="$(jq -r '.adminGroup // false' <<<"${g}")"

  id=""
  if [ "${HAS_KEY}" = true ]; then
    id="$(api GET "/api/user-groups?search=$(urlenc "${name}")" \
      | jq -r --arg n "${name}" '.data[] | select(.name == $n) | .id' | head -1)"
  fi

  if [ -z "${id}" ]; then
    if [ "${DRY_RUN}" = true ]; then
      echo "  [dry-run] reconcile group ${name}"
      id="<pending:${name}>"
    else
      echo "  creating group ${name}"
      id="$(api POST /api/user-groups \
        "$(jq -nc --arg n "${name}" --arg f "${friendly}" '{name: $n, friendlyName: $f}')" \
        | jq -r '.id')"
    fi
  else
    echo "  group ${name} exists"
    if [ "${DRY_RUN}" != true ]; then
      # Enforce declared name/friendlyName (drift correction).
      api PUT "/api/user-groups/${id}" \
        "$(jq -nc --arg n "${name}" --arg f "${friendly}" '{name: $n, friendlyName: $f}')" \
        >/dev/null
    fi
  fi
  [ -n "${id}" ] || die "failed to resolve id for group ${name}"

  if [ "${DRY_RUN}" = true ]; then
    echo "  [dry-run] set custom claims on group ${name}: ${claims}"
  else
    api PUT "/api/custom-claims/user-group/${id}" "${claims}" >/dev/null
  fi

  GROUP_IDS["${name}"]="${id}"
  if [ "${is_admin}" = "true" ]; then
    ADMIN_GROUP_IDS["${name}"]="${id}"
  fi
done < <(jq -c '.[]' <<<"${groups_json}")

# --- OIDC clients --------------------------------------------------------
echo "== reconciling OIDC clients =="
while IFS= read -r c; do
  client_id="$(jq -r '.clientId' <<<"${c}")"
  name="$(jq -r '.name' <<<"${c}")"
  is_public="$(jq -r '.isPublic' <<<"${c}")"
  pkce="$(jq -r '.pkceEnabled' <<<"${c}")"
  callbacks="$(jq -c '.callbackURLs' <<<"${c}")"
  logout="$(jq -c '.logoutCallbackURLs' <<<"${c}")"
  allowed="$(jq -c '.allowedGroups' <<<"${c}")"
  secret_file="$(jq -r '.secretFile // empty' <<<"${c}")"
  secret_key="$(jq -r '.secretKey // empty' <<<"${c}")"

  group_count="$(jq 'length' <<<"${allowed}")"
  is_restricted=false
  [ "${group_count}" -gt 0 ] && is_restricted=true

  # Declared settings (create and update share this DTO).
  body="$(jq -nc \
    --arg name "${name}" --argjson callbacks "${callbacks}" --argjson logout "${logout}" \
    --argjson pub "${is_public}" --argjson pkce "${pkce}" --argjson restr "${is_restricted}" \
    '{name: $name, callbackURLs: $callbacks, logoutCallbackURLs: $logout,
      isPublic: $pub, pkceEnabled: $pkce, isGroupRestricted: $restr}')"

  exists=false
  if [ "${HAS_KEY}" = true ] && [ "$(api_code GET "/api/oidc/clients/${client_id}")" = "200" ]; then
    exists=true
  fi

  placeholder=false
  if [ "${exists}" = true ] && [ -n "${secret_file}" ] && [ -n "${secret_key}" ]; then
    sval="$(sops -d --output-type json "${REPO_ROOT}/${secret_file}" 2>/dev/null \
      | jq -r --arg k "${secret_key}" '.[$k] // empty' 2>/dev/null || true)"
    case "${sval}" in ""|CHANGE_ME_*) placeholder=true ;; esac
  fi

  action="reuse"
  if [ "${exists}" != true ]; then
    action="create"
  elif [ "${placeholder}" = true ]; then
    action="recreate"
  fi

  echo "  ${client_id}: ${action}"

  if [ "${DRY_RUN}" = true ]; then
    continue
  fi

  if [ "${action}" = "recreate" ]; then
    api DELETE "/api/oidc/clients/${client_id}" >/dev/null
  fi

  if [ "${action}" = "create" ] || [ "${action}" = "recreate" ]; then
    api POST /api/oidc/clients \
      "$(jq -nc --arg id "${client_id}" --argjson base "$(jq -c . <<<"${body}")" '$base + {id: $id}')" \
      >/dev/null
  else
    api PUT "/api/oidc/clients/${client_id}" "${body}" >/dev/null
  fi

  # Allowed user groups (names -> ids resolved from the config).
  if [ "${group_count}" -gt 0 ]; then
    ids=()
    missing=""
    while IFS= read -r gname; do
      gid="${GROUP_IDS[${gname}]:-}"
      if [ -n "${gid}" ]; then
        ids+=("${gid}")
      else
        missing="${missing} ${gname}"
      fi
    done < <(jq -r '.[]' <<<"${allowed}")
    if [ -n "${missing}" ]; then
      echo "  warning: ${client_id} references unknown groups:${missing}"
    fi
    user_group_ids="$(printf '%s\n' "${ids[@]}" | jq -R -s 'split("\n") | map(select(. != ""))')"
    api PUT "/api/oidc/clients/${client_id}/allowed-user-groups" \
      "$(jq -nc --argjson ids "${user_group_ids}" '{userGroupIds: $ids}')" \
      >/dev/null
  fi

  # Confidential clients: capture a fresh secret into sops (piped via
  # --value-stdin so the secret never appears in the process list).
  if [ -n "${secret_file}" ] && [ -n "${secret_key}" ] && \
     { [ "${action}" = "create" ] || [ "${action}" = "recreate" ]; }; then
    api POST "/api/oidc/clients/${client_id}/secret" | jq -r '.secret' \
      | sops set --idempotent --value-stdin "${REPO_ROOT}/${secret_file}" "[\"${secret_key}\"]"
    echo "  generated secret for ${client_id} -> ${secret_file}::${secret_key}"
  fi

  # Clean up the stale *_oidc_client_id sops key from the manual era.
  if [ -n "${secret_file}" ] && [[ "${secret_key}" == *_secret ]]; then
    stale_key="${secret_key%_secret}_id"
    if sops -d --output-type json "${REPO_ROOT}/${secret_file}" 2>/dev/null \
        | jq -e --arg k "${stale_key}" 'has($k)' >/dev/null 2>&1; then
      sops unset --idempotent "${REPO_ROOT}/${secret_file}" "[\"${stale_key}\"]"
      echo "  removed stale sops key ${stale_key} from ${secret_file}"
    fi
  fi
done < <(jq -c '.[]' <<<"${clients_json}")

# --- admin user ----------------------------------------------------------
if [ -n "${ADMIN_USER}" ]; then
  if [ ${#ADMIN_GROUP_IDS[@]} -eq 0 ]; then
    echo "== no adminGroup groups declared; skipping admin user =="
  else
    echo "== assigning ${ADMIN_USER} to admin groups =="
    user_id=""
    if [ "${HAS_KEY}" = true ]; then
      user_id="$(api GET "/api/users?search=$(urlenc "${ADMIN_USER}")" \
        | jq -r --arg u "${ADMIN_USER}" '.data[] | select(.username == $u) | .id' | head -1)"
    fi
    if [ -z "${user_id}" ]; then
      if [ "${DRY_RUN}" = true ]; then
        echo "  [dry-run] create user ${ADMIN_USER}"
        user_id="<pending>"
      else
        echo "  creating user ${ADMIN_USER}"
        user_id="$(api POST /api/users \
          "$(jq -nc --arg u "${ADMIN_USER}" '{username: $u, isAdmin: true}')" \
          | jq -r '.id')"
      fi
    fi

    desired="$(printf '%s\n' "${ADMIN_GROUP_IDS[@]}" | jq -R -s 'split("\n") | map(select(. != ""))')"
    current="[]"
    if [ "${HAS_KEY}" = true ] && [ "${DRY_RUN}" != true ]; then
      current="$(api GET "/api/users/${user_id}" | jq -c '[.userGroups[].id]')"
    fi
    merged="$(jq -nc --argjson cur "${current}" --argjson des "${desired}" '[($cur + $des) | unique[]]')"

    if [ "${DRY_RUN}" = true ]; then
      echo "  [dry-run] add ${ADMIN_USER} to admin groups"
    elif [ "${merged}" != "${current}" ]; then
      api PUT "/api/users/${user_id}/user-groups" \
        "$(jq -nc --argjson ids "${merged}" '{userGroupIds: $ids}')" \
        >/dev/null
      echo "  added ${ADMIN_USER} to admin groups"
    else
      echo "  ${ADMIN_USER} already in all admin groups"
    fi
  fi
else
  echo "== no --admin-user given; skipping admin group assignment =="
fi

echo "== done =="
echo "Review the modified sops files (git diff), then commit them and run a darwin-rebuild."
