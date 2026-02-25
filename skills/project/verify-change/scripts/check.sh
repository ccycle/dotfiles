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
  
  if [ "$(is_system_nested "$flake_path" "$profile")" == "true" ]; then
    # Nested: profile.system.system
    local target="${flake_path}#darwinConfigurations.${profile}.${SYSTEM}.system"
    echo "Target: $target"
    nix build "$target" --impure -L --dry-run
  else
    # Direct: profile.system
    local target="${flake_path}#darwinConfigurations.${profile}.system"
    
    # Verify if it's compatible with current system if possible
    local profile_system=$(nix eval "${flake_path}#darwinConfigurations.${profile}.pkgs.system" --raw --impure 2>/dev/null || echo "$SYSTEM")
    if [ "$profile_system" != "$SYSTEM" ]; then
      echo "Skipping $profile (incompatible system: $profile_system)"
      return 0
    fi
    
    echo "Target: $target"
    nix build "$target" --impure -L --dry-run
  fi
  echo "✅ $profile dry-run passed."
}

# --- Main Execution ---

# 1. Syntax check
check_syntax
echo ""

# 2. Extract and check profiles from root flake
echo "=== 📋 Discovering profiles in root flake ==="
ROOT_PROFILES=$(get_profiles ".")
echo "Found: $ROOT_PROFILES"

for profile in $(echo "$ROOT_PROFILES" | jq -r '.[]'); do
  build_dry_run "." "$profile"
  echo ""
done

# 3. Extract and check profiles from bootstrap flake
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
