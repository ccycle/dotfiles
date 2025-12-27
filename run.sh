#!/bin/sh
set -eu

# Always run against the repo flake so dotfiles modules are included even if CWD differs.
repo_root="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
user="${USER:-}"

nix --extra-experimental-features "nix-command flakes" \
  run home-manager -- switch -L --impure --flake "${repo_root}#${user}"