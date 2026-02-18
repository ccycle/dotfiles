#!/bin/sh
set -eu

repo_root="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"

sudo -H nix --extra-experimental-features "nix-command flakes" run "${repo_root}#darwin-rebuild" -- switch --flake "${repo_root}#private.$(uname -m | sed 's/arm64/aarch64/')-darwin" --impure -L
