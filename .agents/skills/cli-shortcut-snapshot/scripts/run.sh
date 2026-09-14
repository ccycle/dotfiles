#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH='' cd -- "$(dirname -- "$0")/../../../.." && pwd)"

exec "$repo_root/tests/cli-shortcut-snapshot/scripts/run.sh" "$@"
