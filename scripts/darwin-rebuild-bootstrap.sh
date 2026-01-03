#!/bin/sh
set -eu

repo_root="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"

sudo -H nix run "${repo_root}#darwin-rebuild" -- switch --flake "${repo_root}/bootstrap#bootstrap.$(uname -m | sed 's/arm64/aarch64/')-darwin" --impure -L --show-trace
