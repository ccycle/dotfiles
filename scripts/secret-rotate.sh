#!/usr/bin/env bash
# Atomic secret rotation: edit -> verify -> commit -> rebuild.
#
# Encapsulates the full rotation workflow for a single sops-encrypted
# secrets file into one command:
#
#   1. Opens the file in $EDITOR via sops (re-encrypts on save).
#   2. Verifies recipient integrity against modules/sops/age-keys.nix
#      via scripts/sops/check-recipients.sh (fails loudly if the edit
#      broke the declared key rules).
#   3. Commits the change with a structured message.
#   4. Runs scripts/darwin-rebuild.sh for the chosen profile so the new
#      value reaches /run/secrets and consuming services restart.
#
# Security notes:
#   - Decrypted content is never echoed; only git diff --stat metadata
#     is displayed.
#   - The commit contains only the target file (working tree must be
#     clean beforehand, unless --allow-dirty is passed).
#
# Usage:
#   scripts/secret-rotate.sh --key <key> --value <val> [--profile <name>]
#                            [--no-rebuild] <path/to/secrets.yaml>
#   scripts/secret-rotate.sh [--profile <name>] [--message <msg>]
#                            [--no-rebuild] [--allow-dirty]
#                            <path/to/secrets.yaml>
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

NIX="nix --extra-experimental-features nix-command --extra-experimental-features flakes"

usage() {
  cat <<EOF
Usage: $(basename -- "$0") [options] <path/to/secrets.yaml>

Rotate a secret inside a sops-encrypted YAML file and propagate it.

Two modes:
  Key mode (non-interactive):
    --key <key> --value <val>   Set a specific key via sops set.
    Example: $(basename -- "$0") --key attic.push-token --value abc123 secrets/attic/secrets.yaml

  Editor mode (interactive):
    Without --key, opens the file in \$EDITOR via sops for manual editing.

Options:
  -k, --key <key>       Dot-separated key path to rotate (enables key mode).
  -v, --value <val>     New value for the key (required with --key).
  -p, --profile <name>  darwin profile to rebuild (e.g. private,
                        mac-mini-m4-pro, bootstrap). Prompted for when
                        omitted on a TTY.
  -m, --message <msg>   Custom commit subject
                        (default: "rotate(secrets): <file> key=<key>")
      --no-rebuild      Stop after committing; skip darwin-rebuild.
      --allow-dirty     Permit rotation even with unrelated uncommitted
                        changes (the commit still stages only the target
                        file).
  -h, --help            Show this help.
EOF
}

die() { echo "Error: $*" >&2; exit 1; }

profile=""
message=""
no_rebuild=0
allow_dirty=0
key=""
value=""
file=""

while [ $# -gt 0 ]; do
  case "$1" in
    -k|--key)      [ $# -ge 2 ] || die "--key requires a value"; key="$2"; shift 2 ;;
    -v|--value)    [ $# -ge 2 ] || die "--value requires a value"; value="$2"; shift 2 ;;
    -p|--profile)  [ $# -ge 2 ] || die "--profile requires a value"; profile="$2"; shift 2 ;;
    -m|--message)  [ $# -ge 2 ] || die "--message requires a value"; message="$2"; shift 2 ;;
    --no-rebuild)  no_rebuild=1; shift ;;
    --allow-dirty) allow_dirty=1; shift ;;
    -h|--help)     usage; exit 0 ;;
    *)             file="$1"; shift ;;
  esac
done

[ -n "${file}" ] || { usage >&2; exit 1; }
[ -f "${file}" ] || die "secrets file not found: ${file}"
command -v sops >/dev/null 2>&1 || die "sops is not installed or not on PATH"

# Validate --key / --value pairing
if [ -n "${key}" ] && [ -z "${value}" ]; then
  die "--key requires --value"
fi
if [ -z "${key}" ] && [ -n "${value}" ]; then
  die "--value requires --key"
fi
key_mode=0
[ -n "${key}" ] && key_mode=1

# --- Pre-flight: refuse to mix unrelated changes into the rotation commit ---
if ! git diff --quiet -- . ':!.local' || ! git diff --cached --quiet -- . ':!.local'; then
  if [ "${allow_dirty}" -ne 1 ]; then
    echo "Working tree has uncommitted changes:" >&2
    git status --short >&2
    die "commit would not be atomic; pass --allow-dirty to proceed anyway"
  fi
fi

# --- Sanity check BEFORE opening the editor ---
echo "==> Pre-edit recipient check: ${file}"
"${REPO_ROOT}/scripts/sops/check-recipients.sh" >/dev/null \
  || die "recipient check failed before edit; fix key rules first (see scripts/sops/)"

# --- Edit phase ---
before_hash="$(git hash-object -- "${file}")"

if [ "${key_mode}" -eq 1 ]; then
  # Key mode: set a specific key non-interactively
  # sops set expects JSON-encoded values; wrap strings in quotes.
  echo "==> Setting '${key}' in ${file}"
  sops set "${file}" "${key}" "\"${value}\""
else
  # Editor mode: open in $EDITOR via sops (re-encrypts on save)
  echo "==> Opening ${file} in \${EDITOR:-vi} via sops..."
  # sops exits with code 200 when the editor closed without changes; that is
  # a normal outcome ("nothing to rotate"), not an error.
  set +e
  EDITOR="${EDITOR:-vi}" sops "${file}"
  sops_rc=$?
  set -e

  if [ "${sops_rc}" -eq 200 ]; then
    echo "No changes made to ${file}; nothing to rotate."
    exit 0
  elif [ "${sops_rc}" -ne 0 ]; then
    die "sops exited with code ${sops_rc}; aborting without committing."
  fi
fi

after_hash="$(git hash-object -- "${file}")"
if [ "${before_hash}" = "${after_hash}" ]; then
  echo "No changes made to ${file}; nothing to rotate."
  exit 0
fi

# --- Post-edit verification ---
echo "==> Post-edit recipient check (all secrets files)..."
"${REPO_ROOT}/scripts/sops/check-recipients.sh" \
  || die "edit broke recipient rules; NOT committing. Inspect 'git diff ${file}' and revert if needed."

echo "==> Change summary (metadata only):"
git diff --stat -- "${file}"

# --- Commit ---
if [ -n "${message}" ]; then
  : # use user-provided message
elif [ "${key_mode}" -eq 1 ]; then
  message="rotate(secrets): ${file} key=${key}"
else
  message="rotate(secrets): ${file}"
fi
git add -- "${file}"
git commit -m "${message}"
echo "==> Committed: ${message}"

# --- Rebuild ---
if [ "${no_rebuild}" -eq 1 ]; then
  echo "==> --no-rebuild given; services still use the OLD value until the next switch."
  exit 0
fi

# Discover available profiles exactly like scripts/darwin-rebuild.sh does.
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

profiles="$(echo "${all_configs}" | sed 's/\.\(aarch64-darwin\|x86_64-darwin\)$//' | sort -u | grep -v '^$' || true)"
[ -n "${profiles}" ] || profiles="bootstrap"

if [ -z "${profile}" ]; then
  if [ ! -t 0 ]; then
    echo "Available profiles:" >&2
    echo "${profiles}" | sed 's/^/  /' >&2
    die "non-interactive session: pass --profile explicitly"
  fi
  echo "==> Which profile consumes this secret?"
  # Recommend the profile whose name matches the local hostname
  # (informational only; the user confirms explicitly).
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
  done <<< "${profiles}"

  default_reply="${recommended:-}"
  printf "Profile [%s]: " "${default_reply:-required}"
  read -r reply
  if [ -z "${reply}" ] && [ -n "${default_reply}" ]; then
    profile="${default_reply}"
  else
    case "${reply}" in
      ''|*[!0-9]*) profile="${reply}" ;;
      *) profile="$(sed -n "${reply}p" <<< "${profiles}")" ;;
    esac
  fi
fi

echo "==> Rebuilding profile: ${profile}"
exec "${REPO_ROOT}/scripts/darwin-rebuild.sh" "${profile}"