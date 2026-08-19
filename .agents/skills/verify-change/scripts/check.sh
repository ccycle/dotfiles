#!/usr/bin/env bash
set -e

# --- Configuration & Helpers ---
SYSTEM=$(nix eval --raw --impure --expr 'builtins.currentSystem')
echo "Detected system: $SYSTEM"

# Current host identity, used to tell host profiles from foreign ones. On
# macOS the declared networking.hostName matches `scutil --get LocalHostName`.
LOCAL_HOST="$(scutil --get LocalHostName 2>/dev/null || hostname -s)"
LOCAL_HOST="$(echo "$LOCAL_HOST" | tr '[:upper:]' '[:lower:]' | sed 's/\.local$//')"
echo "Detected host: $LOCAL_HOST"

function check_syntax() {
  echo "=== 🔍 Checking Nix Syntax ==="
  find . -name "*.nix" -not -path "*/node_modules/*" -not -path "*/.git/*" -print0 | xargs -0 -n 1 nix-instantiate --parse > /dev/null
  echo "✅ Syntax check passed."
}

function check_structure() {
  echo "=== 📦 Checking Package by Feature structure ==="
  local report
  report=$(nix eval --json --impure \
    --expr 'import ./scripts/package-by-feature/check.nix { repoRoot = ./.; }')
  if [ "$(echo "$report" | jq -r '.ok')" != "true" ]; then
    echo "$report" | jq -r '.violations[] | "❌ [\(.rule)] \(.file): \(.message)"'
    echo "Structure check failed ($(echo "$report" | jq -r '.count') violation(s))."
    echo "Rules are declared in scripts/package-by-feature/rules.nix."
    return 1
  fi
  echo "✅ Structure check passed."
}

function check_recipients() {
  echo "=== 🔐 Checking sops recipient drift against age key ledger ==="
  "${REPO_ROOT}/scripts/sops/check-recipients.sh"
  echo ""
}

# Flatten darwinConfigurations into fully-qualified config paths. Entries are
# either direct darwinSystem results (mac-mini-m4) or per-architecture attrsets
# (private.<arch>); resolving both here lets every downstream step use the
# uniform path <flake>#darwinConfigurations.<config>.<attr>.
function list_configs() {
  nix eval "${1}#darwinConfigurations" --apply '
    configs:
    let isConfig = v: v ? system;
        resolve = name:
          let v = configs.${name};
          in if isConfig v then [ name ]
             else map (sub: "${name}.${sub}")
               (builtins.filter (sub: isConfig v.${sub}) (builtins.attrNames v));
    in builtins.concatStringsSep " " (builtins.concatMap resolve (builtins.attrNames configs))
  ' --raw --impure
}

# Declared hostName of a config; "null" means the profile is host-agnostic
# (no host module pins it, so it is meant to build on any machine).
function get_config_host() {
  nix eval "${1}#darwinConfigurations.${2}.config.networking.hostName" --json --impure 2>/dev/null | jq -r .
}

# Machine-local state (.local/storage) is only valid for the current host.
# Foreign profiles would fail eval-time assertions because their services'
# storage volumes are not configured on this machine, so dry-run them against
# a placeholder that satisfies every known volume assertion. Keep the service
# list in sync with the `assertions` in modules/<service>/darwin.nix.
function get_placeholder_storage() {
  local dir="${REPO_ROOT}/.local/.verify-placeholder-storage"
  mkdir -p "${dir}/vol"
  cat > "${dir}/flake.nix" <<EOF
{
  outputs = { ... }: {
    darwinModules.default = { ... }: {
      custom.storage.volumes = {
        forgejo = "${dir}/vol";
        gitlab = "${dir}/vol";
        immich = "${dir}/vol";
        llm-server = "${dir}/vol";
        monitoring = "${dir}/vol";
        opencloud = "${dir}/vol";
      };
    };
  };
}
EOF
  echo "${dir}"
}

function build_dry_run() {
  local flake_path=$1
  local config=$2
  local profile="${config%%.*}"

  echo "=== 🏗️ Build Dry-Run: ${profile} (${flake_path}) ==="

  # Skip configs built for another architecture.
  local config_system
  config_system="$(nix eval "${flake_path}#darwinConfigurations.${config}.pkgs.system" --raw --impure 2>/dev/null || echo "$SYSTEM")"
  if [ "$config_system" != "$SYSTEM" ]; then
    echo "Skipping ${profile} (incompatible system: $config_system)"
    return 0
  fi

  local override_args=()
  if [ "${flake_path}" != "./bootstrap" ]; then
    # Host-agnostic configs and the current host's config use the real
    # machine-local storage; foreign hosts use a placeholder so their volume
    # assertions cannot fail from missing machine state.
    local storage_override=""
    local host
    host="$(get_config_host "$flake_path" "$config")"
    if [ -n "${host}" ] && [ "${host}" != "null" ] && [ "${host}" != "${LOCAL_HOST}" ]; then
      echo "  (host '${host}' != current '${LOCAL_HOST}': using placeholder storage config)"
      storage_override="$(get_placeholder_storage)"
    elif [ -d "${REPO_ROOT}/.local/storage" ]; then
      storage_override="${REPO_ROOT}/.local/storage"
    fi
    if [ -n "${storage_override}" ]; then
      override_args+=(--override-input storage-config "path:${storage_override}")
    fi
    if [ -d "${REPO_ROOT}/.local/dotfiles" ]; then
      override_args+=(--override-input dotfiles-config "path:${REPO_ROOT}/.local/dotfiles")
    fi
    if [ -d "${REPO_ROOT}/.local/obsidian-vault" ]; then
      override_args+=(--override-input obsidian-vault-config "path:${REPO_ROOT}/.local/obsidian-vault")
    fi
  fi

  local target="${flake_path}#darwinConfigurations.${config}.system"
  echo "Target: $target"
  nix build "$target" --impure -L --dry-run "${override_args[@]}"
  echo "✅ $profile dry-run passed."
}

# --- Main Execution ---

# 0. Ensure Nix SSL cert exists (required to reach binary caches)
if [ -f /etc/nix/nix.conf ] && grep -q 'ssl-cert-file' /etc/nix/nix.conf; then
  CERT_FILE=$(grep 'ssl-cert-file' /etc/nix/nix.conf | awk '{print $3}')
  if [ -n "$CERT_FILE" ] && [ ! -f "$CERT_FILE" ]; then
    echo "=== 🔐 Regenerating missing Nix SSL cert: $CERT_FILE ==="
    security export -t certs -f pemseq \
      -k /System/Library/Keychains/SystemRootCertificates.keychain \
      -o /tmp/nix-certs-root.pem
    security export -t certs -f pemseq \
      -k /Library/Keychains/System.keychain \
      -o /tmp/nix-certs-system.pem 2>/dev/null || cp /dev/null /tmp/nix-certs-system.pem
    cat /tmp/nix-certs-root.pem /tmp/nix-certs-system.pem | sudo tee "$CERT_FILE" > /dev/null
    rm -f /tmp/nix-certs-root.pem /tmp/nix-certs-system.pem
    echo "✅ SSL cert regenerated."
  fi
fi

# 0.5. Ensure machine-local .local state for this checkout. Worktrees never
# carry the gitignored .local/ directory; restore storage/obsidian-vault from
# the main checkout and regenerate dotfiles.dir so the dry-run validates THIS
# checkout's files instead of main's.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
echo "=== 📂 Ensuring machine-local .local state ==="
"${REPO_ROOT}/scripts/ensure-local.sh"
echo ""

# 1. Syntax check
check_syntax
echo ""

# 2. Package by Feature structure check
check_structure
echo ""

# 2.5. Sops recipient check against the age key ledger
check_recipients

# 3. Build dry-run every compatible profile from the root and bootstrap flakes
echo "=== 📋 Discovering profiles in root flake ==="
ROOT_CONFIGS=$(list_configs ".")
echo "Found: $ROOT_CONFIGS"
for config in $ROOT_CONFIGS; do
  build_dry_run "." "$config"
  echo ""
done

if [ -d "./bootstrap" ]; then
  echo "=== 📋 Discovering profiles in bootstrap flake ==="
  BOOTSTRAP_CONFIGS=$(list_configs "./bootstrap")
  echo "Found: $BOOTSTRAP_CONFIGS"
  for config in $BOOTSTRAP_CONFIGS; do
    build_dry_run "./bootstrap" "$config"
    echo ""
  done
fi

echo "🎉 All checks passed! You are safe to commit."
