#!/bin/sh
set -eu

USAGE="Usage: $(basename -- "$0") <profile>

Profiles:
  bootstrap    Run bootstrap flake (provisions sops-nix secrets on fresh install)
  private      Run main flake for personal Darwin configuration
  mac-mini-m4  Run main flake for Mac Mini M4 configuration"

if [ $# -ne 1 ]; then
  echo "${USAGE}" >&2
  exit 1
fi

profile="$1"
repo_root="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
arch="$(nix --extra-experimental-features "nix-command flakes" eval --impure --raw --expr 'builtins.currentSystem')"

case "${profile}" in
  bootstrap)
    flake_root="${repo_root}/bootstrap"
    app="default"
    config="bootstrap.${arch}"
    ;;
  private)
    flake_root="${repo_root}"
    app="darwin-rebuild"
    config="private.${arch}"
    ;;
  mac-mini-m4)
    flake_root="${repo_root}"
    app="darwin-rebuild"
    config="mac-mini-m4"
    ;;
  *)
    echo "Unknown profile: ${profile}" >&2
    echo "" >&2
    echo "${USAGE}" >&2
    exit 1
    ;;
esac

sudo -H nix --extra-experimental-features "nix-command flakes" run "${flake_root}#${app}" -- switch --flake "${flake_root}#${config}" --impure -L
