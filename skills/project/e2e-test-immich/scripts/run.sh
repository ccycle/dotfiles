#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH='' cd -- "$(dirname -- "$0")/../../../.." && pwd)"

exec "$repo_root/tests/e2e-immich/scripts/run.sh" "$@"
