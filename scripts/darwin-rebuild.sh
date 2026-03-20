#!/bin/sh
set -eu

NIX="nix --extra-experimental-features nix-command --extra-experimental-features flakes"

repo_root="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
arch="$(${NIX} eval --impure --raw --expr 'builtins.currentSystem')"

# Discover available profiles from the main flake's darwinConfigurations
main_profiles="$(${NIX} eval "${repo_root}#darwinConfigurations" --apply 'x: builtins.concatStringsSep "\n" (builtins.attrNames x)' --raw 2>/dev/null || echo "")"

show_usage() {
  echo "Usage: $(basename -- "$0") <profile>"
  echo ""
  echo "Profiles:"
  echo "  bootstrap        Run bootstrap flake (provisions sops-nix secrets on fresh install)"
  if [ -n "${main_profiles}" ]; then
    echo "${main_profiles}" | while IFS= read -r p; do
      printf "  %-18s Run main flake configuration\n" "${p}"
    done
  fi
}

if [ $# -ne 1 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  show_usage >&2
  exit 1
fi

profile="$1"

if [ "${profile}" = "bootstrap" ]; then
  flake_root="${repo_root}/bootstrap"
  app="default"
  config="bootstrap.${arch}"
else
  flake_root="${repo_root}"
  app="darwin-rebuild"

  # Check if the profile exists as-is in darwinConfigurations
  if echo "${main_profiles}" | grep -qx "${profile}"; then
    config="${profile}"
  # Check if profile.${arch} exists
  elif echo "${main_profiles}" | grep -qx "${profile}\.${arch}"; then
    config="${profile}.${arch}"
  else
    echo "Unknown profile: ${profile}" >&2
    echo "" >&2
    show_usage >&2
    exit 1
  fi
fi

sudo -H ${NIX} run "${flake_root}#${app}" -- switch --flake "${flake_root}#${config}" --impure -L
