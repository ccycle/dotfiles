#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
cd "${REPO_ROOT}"

NIX="nix --extra-experimental-features nix-command --extra-experimental-features flakes"
SOPS_WITH_RBW="${REPO_ROOT}/.agents/skills/credentials-manager/scripts/sops-with-rbw"
BWS_AGENT="${REPO_ROOT}/modules/agents/skills/bws/scripts/bws-agent"

usage() {
  cat <<EOF
Usage: $(basename -- "$0") --key <key> (--from-prompt | --from-bws <project-id> <bws-key>)
                          [--profile <name>] [--message <msg>] [--no-rebuild] [--allow-dirty]
                          <path/to/secrets.yaml>

Replace one key in a sops-encrypted YAML file, commit it, and darwin-rebuild.
No other key is ever decrypted to the screen, and the new value never appears
on a command line.

  -k, --key <key>        Dot-separated key path to replace (e.g. forgejo_api_token).
      --from-prompt      Read the new value from a hidden prompt (for the user's terminal).
      --from-bws <project-id> <bws-key>
                         Take the new value from a Bitwarden Secrets Manager project
                         through bws-agent (for agents; the user stores the value in
                         the web vault first).
  -p, --profile <name>   darwin profile to rebuild. Prompted for when omitted on a TTY.
  -m, --message <msg>    Commit subject (default: "rotate(secrets): <file> key=<key>").
      --no-rebuild       Stop after committing; skip darwin-rebuild.
      --allow-dirty      Permit unrelated uncommitted changes (only the target file is staged).
  -h, --help             Show this help.
EOF
}

die() {
  echo "Error: $*" >&2
  exit 1
}

profile=""
message=""
no_rebuild=0
allow_dirty=0
key=""
source_kind=""
bws_project=""
bws_key=""
file=""

while [ $# -gt 0 ]; do
  case "$1" in
  -k | --key)
    [ $# -ge 2 ] || die "--key requires a value"
    key="$2"
    shift 2
    ;;
  --from-prompt)
    source_kind=prompt
    shift
    ;;
  --from-bws)
    [ $# -ge 3 ] || die "--from-bws requires <project-id> <bws-key>"
    source_kind=bws
    bws_project="$2"
    bws_key="$3"
    shift 3
    ;;
  -p | --profile)
    [ $# -ge 2 ] || die "--profile requires a value"
    profile="$2"
    shift 2
    ;;
  -m | --message)
    [ $# -ge 2 ] || die "--message requires a value"
    message="$2"
    shift 2
    ;;
  --no-rebuild)
    no_rebuild=1
    shift
    ;;
  --allow-dirty)
    allow_dirty=1
    shift
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  -*)
    die "unknown option: $1 (whole-file editing is not supported; replace one key with --key)"
    ;;
  *)
    file="$1"
    shift
    ;;
  esac
done

[ -n "${file}" ] || {
  usage >&2
  exit 1
}
[ -n "${key}" ] || die "--key is required"
[ -n "${source_kind}" ] || die "pass --from-prompt or --from-bws <project-id> <bws-key>"
[ -f "${file}" ] || die "secrets file not found: ${file}"
command -v sops >/dev/null 2>&1 || die "sops is not installed or not on PATH"
if [ "${source_kind}" = bws ]; then
  [[ ${bws_key} =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || die "bws key must be a shell variable name: ${bws_key}"
fi

index="$(jq -rn --arg k "${key}" '$k | split(".") | map("[" + tojson + "]") | join("")')"

if ! git diff --quiet -- . ':!.local' || ! git diff --cached --quiet -- . ':!.local'; then
  if [ "${allow_dirty}" -ne 1 ]; then
    echo "Working tree has uncommitted changes:" >&2
    git status --short >&2
    die "commit would not be atomic; pass --allow-dirty to proceed anyway"
  fi
fi

echo "==> Pre-change recipient check: ${file}"
"${REPO_ROOT}/.agents/skills/credentials-manager/scripts/check-recipients.sh" >/dev/null ||
  die "recipient check failed before the change; fix key rules first (see modules/sops/age-keys.nix)"

before_hash="$(git hash-object -- "${file}")"

echo "==> Setting '${key}' in ${file}"
case "${source_kind}" in
prompt)
  read -rsp "New value for ${key} (hidden): " value
  echo
  [ -n "${value}" ] || die "empty value; nothing changed"
  printf '%s' "${value}" | jq -Rs . | "${SOPS_WITH_RBW}" set --value-stdin "${file}" "${index}"
  unset value
  ;;
bws)
  printf -v set_cmd '[ -n "${%s:-}" ] || { echo "bws key %s is missing or empty" >&2; exit 3; }; printf %%s "$%s" | jq -Rs . | %q set --value-stdin %q %q' \
    "${bws_key}" "${bws_key}" "${bws_key}" "${SOPS_WITH_RBW}" "${file}" "${index}"
  "${BWS_AGENT}" run "${bws_project}" -- "${set_cmd}"
  ;;
esac

after_hash="$(git hash-object -- "${file}")"
if [ "${before_hash}" = "${after_hash}" ]; then
  die "${file} did not change; not committing"
fi

echo "==> Post-change recipient check (all secrets files)..."
"${REPO_ROOT}/.agents/skills/credentials-manager/scripts/check-recipients.sh" ||
  die "the change broke recipient rules; NOT committing. Inspect 'git diff ${file}' and revert if needed."

echo "==> Change summary (metadata only):"
git diff --stat -- "${file}"

[ -n "${message}" ] || message="rotate(secrets): ${file} key=${key}"
git add -- "${file}"
git commit -m "${message}"
echo "==> Committed: ${message}"

if [ "${no_rebuild}" -eq 1 ]; then
  echo "==> --no-rebuild given; services still use the OLD value until the next switch."
  exit 0
fi

all_configs="$(${NIX} eval "${REPO_ROOT}#darwinConfigurations" --apply '
  configs:
  let
    isConfig = v: v ? system;
    resolve = name:
      let v = configs.${name};
      in if isConfig v then [ name ]
         else map (sub: "${name}.${sub}")
           (builtins.filter (sub: isConfig v.${sub}) (builtins.attrNames v));
  in builtins.concatStringsSep "\n"
    (builtins.concatMap resolve (builtins.attrNames configs))
' --raw 2>/dev/null || echo "")"

profiles="$(echo "${all_configs}" | sed -E 's/\.(aarch64|x86_64)-darwin$//' | sort -u | grep -v '^$' || true)"
[ -n "${profiles}" ] || profiles="bootstrap"

if [ -z "${profile}" ]; then
  if [ ! -t 0 ]; then
    echo "Available profiles:" >&2
    echo "${profiles}" | sed 's/^/  /' >&2
    die "non-interactive session: pass --profile explicitly"
  fi
  echo "==> Which profile consumes this secret?"
  host_hint="$(scutil --get LocalHostName 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9-' '-' || true)"
  recommended=""
  i=0
  while IFS= read -r p; do
    i=$((i + 1))
    mark=""
    if [ -n "${host_hint}" ] && [ -z "${recommended}" ] && printf '%s' "${p}" | grep -q "^${host_hint}"; then
      recommended="${p}"
      mark="  (Recommended)"
    fi
    printf "  %d) %s%s\n" "${i}" "${p}" "${mark}"
  done <<<"${profiles}"

  default_reply="${recommended:-}"
  printf "Profile [%s]: " "${default_reply:-required}"
  read -r reply
  if [ -z "${reply}" ] && [ -n "${default_reply}" ]; then
    profile="${default_reply}"
  else
    case "${reply}" in
    '' | *[!0-9]*) profile="${reply}" ;;
    *) profile="$(sed -n "${reply}p" <<<"${profiles}")" ;;
    esac
  fi
fi

echo "==> Rebuilding profile: ${profile}"
exec "${REPO_ROOT}/.agents/skills/darwin-rebuild/scripts/darwin-rebuild.sh" "${profile}"
