#!/bin/sh
set -eu

repo_root="$(git -C "$(dirname -- "$0")" rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "${repo_root}" ]; then
  repo_root="$(CDPATH='' cd -- "$(dirname -- "$0")/../../../.." && pwd)"
fi

nix develop "${repo_root}#secrets"
