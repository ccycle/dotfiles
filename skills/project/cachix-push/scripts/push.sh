#!/usr/bin/env bash
set -e

# --- Configuration ---
CACHE_NAME="ccycle"
TOKEN_FILE="/run/secrets/cachix-auth-token-ccycle"

# --- Auth Setup ---
# Priority: env var > token file > none
if [ -z "${CACHIX_AUTH_TOKEN:-}" ]; then
  if [ -r "$TOKEN_FILE" ]; then
    echo "Reading Cachix auth token from $TOKEN_FILE"
    export CACHIX_AUTH_TOKEN
    CACHIX_AUTH_TOKEN="$(cat "$TOKEN_FILE")"
  else
    echo "Note: CACHIX_AUTH_TOKEN not set and $TOKEN_FILE not found. Proceeding without explicit auth."
  fi
else
  echo "Using CACHIX_AUTH_TOKEN from environment."
fi

# --- System Detection ---
SYSTEM=$(nix eval --raw --impure --expr 'builtins.currentSystem')
echo "Detected system: $SYSTEM"

# --- Profile Filter (optional argument) ---
FILTER_PROFILE="${1:-}"
if [ -n "$FILTER_PROFILE" ]; then
  echo "Filtering to profile: $FILTER_PROFILE"
fi

# --- Helper: check if a profile attribute is system-nested ---
function is_nested() {
  local flake_path=$1
  local config_attr=$2
  local profile=$3
  nix eval "${flake_path}#${config_attr}.${profile}" \
    --json \
    --apply "attrs: builtins.hasAttr \"${SYSTEM}\" attrs" \
    --impure 2>/dev/null || echo "false"
}

# --- Build & Push: Darwin Configurations ---
function push_darwin_profile() {
  local flake_path=$1
  local profile=$2

  echo "=== Darwin: ${profile} ==="

  if [ "$(is_nested "$flake_path" "darwinConfigurations" "$profile")" == "true" ]; then
    local target="${flake_path}#darwinConfigurations.${profile}.${SYSTEM}.system"
    echo "Target (nested): $target"
    cachix watch-exec "$CACHE_NAME" -- nix build "$target" --impure -L --no-update-lock-file
  else
    local profile_system
    profile_system=$(nix eval "${flake_path}#darwinConfigurations.${profile}.pkgs.system" --raw --impure 2>/dev/null || echo "$SYSTEM")
    if [ "$profile_system" != "$SYSTEM" ]; then
      echo "Skipping $profile (incompatible system: $profile_system)"
      return 0
    fi
    local target="${flake_path}#darwinConfigurations.${profile}.system"
    echo "Target (flat): $target"
    cachix watch-exec "$CACHE_NAME" -- nix build "$target" --impure -L --no-update-lock-file
  fi
  echo "Done: $profile"
}

# --- Build & Push: Home Manager Configurations ---
function push_home_profile() {
  local flake_path=$1
  local profile=$2

  echo "=== Home: ${profile} ==="

  if [ "$(is_nested "$flake_path" "homeConfigurations" "$profile")" == "true" ]; then
    local target="${flake_path}#homeConfigurations.${profile}.${SYSTEM}.activationPackage"
    echo "Target (nested): $target"
    cachix watch-exec "$CACHE_NAME" -- nix build "$target" --impure -L --no-update-lock-file
  else
    local target="${flake_path}#homeConfigurations.${profile}.activationPackage"
    echo "Target (flat): $target"
    cachix watch-exec "$CACHE_NAME" -- nix build "$target" --impure -L --no-update-lock-file
  fi
  echo "Done: $profile"
}

# --- Main ---

REPO_ROOT="$(git rev-parse --show-toplevel)"

echo ""
echo "=== Discovering Darwin profiles ==="
DARWIN_PROFILES=$(nix eval "${REPO_ROOT}#darwinConfigurations" --json --apply 'builtins.attrNames' --impure)
echo "Found: $DARWIN_PROFILES"

for profile in $(echo "$DARWIN_PROFILES" | jq -r '.[]'); do
  if [ -n "$FILTER_PROFILE" ] && [ "$profile" != "$FILTER_PROFILE" ]; then
    continue
  fi
  push_darwin_profile "$REPO_ROOT" "$profile"
  echo ""
done

echo ""
echo "=== Discovering Home Manager profiles ==="
HOME_PROFILES=$(nix eval "${REPO_ROOT}#homeConfigurations" --json --apply 'builtins.attrNames' --impure)
echo "Found: $HOME_PROFILES"

for profile in $(echo "$HOME_PROFILES" | jq -r '.[]'); do
  if [ -n "$FILTER_PROFILE" ] && [ "$profile" != "$FILTER_PROFILE" ]; then
    continue
  fi
  push_home_profile "$REPO_ROOT" "$profile"
  echo ""
done

echo "All builds complete. Store paths pushed to cachix cache: $CACHE_NAME"
