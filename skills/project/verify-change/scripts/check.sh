#!/usr/bin/env bash
set -e

# --- Configuration & Helpers ---
SYSTEM=$(nix eval --raw --impure --expr 'builtins.currentSystem')
echo "Detected system: $SYSTEM"

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

function get_profiles() {
  local flake_path=$1
  nix eval "${flake_path}#darwinConfigurations" --json --apply 'builtins.attrNames' --impure
}

function is_system_nested() {
  local flake_path=$1
  local profile=$2
  # Check if the profile has the current system as a sub-attribute
  nix eval "${flake_path}#darwinConfigurations.${profile}" --json --apply "attrs: builtins.hasAttr \"${SYSTEM}\" attrs" --impure
}

function build_dry_run() {
  local flake_path=$1
  local profile=$2

  echo "=== 🏗️ Build Dry-Run: ${profile} (${flake_path}) ==="

  local storage_override=()
  if [ "${flake_path}" != "./bootstrap" ]; then
    local repo_root
    repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
    local storage_local="${repo_root}/.local/storage"
    if [ -d "${storage_local}" ]; then
      storage_override=(--override-input storage-config "path:${storage_local}")
    fi
  fi

  if [ "$(is_system_nested "$flake_path" "$profile")" == "true" ]; then
    # Nested: profile.system.system
    local target="${flake_path}#darwinConfigurations.${profile}.${SYSTEM}.system"
    echo "Target: $target"
    nix build "$target" --impure -L --dry-run "${storage_override[@]}"
  else
    # Direct: profile.system
    local target="${flake_path}#darwinConfigurations.${profile}.system"

    # Verify if it's compatible with current system if possible
    local profile_system
    profile_system=$(nix eval "${flake_path}#darwinConfigurations.${profile}.pkgs.system" --raw --impure 2>/dev/null || echo "$SYSTEM")
    if [ "$profile_system" != "$SYSTEM" ]; then
      echo "Skipping $profile (incompatible system: $profile_system)"
      return 0
    fi

    echo "Target: $target"
    nix build "$target" --impure -L --dry-run "${storage_override[@]}"
  fi
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

# 1. Syntax check
check_syntax
echo ""

# 2. Package by Feature structure check
check_structure
echo ""

# 3. Extract and check profiles from root flake
echo "=== 📋 Discovering profiles in root flake ==="
ROOT_PROFILES=$(get_profiles ".")
echo "Found: $ROOT_PROFILES"

for profile in $(echo "$ROOT_PROFILES" | jq -r '.[]'); do
  build_dry_run "." "$profile"
  echo ""
done

# 4. Extract and check profiles from bootstrap flake
if [ -d "./bootstrap" ]; then
  echo "=== 📋 Discovering profiles in bootstrap flake ==="
  BOOTSTRAP_PROFILES=$(get_profiles "./bootstrap")
  echo "Found: $BOOTSTRAP_PROFILES"

  for profile in $(echo "$BOOTSTRAP_PROFILES" | jq -r '.[]'); do
    build_dry_run "./bootstrap" "$profile"
    echo ""
  done
fi

echo "🎉 All checks passed! You are safe to commit."
