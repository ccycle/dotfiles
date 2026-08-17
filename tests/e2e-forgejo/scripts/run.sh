#!/usr/bin/env bash
# Orchestrates the Forgejo E2E suite: brings up the isolated stack
# (scripts/stack.sh), runs the Playwright spec against it, publishes the
# HTML+trace report, then tears the stack down. See
# tests/e2e-forgejo/design.md for the full rationale.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
E2E_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$E2E_DIR/../.." && pwd)"
STACK="$SCRIPT_DIR/stack.sh"
ENV_FILE="$E2E_DIR/.env"
WORKTREE_ID="$(basename "$REPO_ROOT")"
# modules/static-reports/options.nix's default dataDir. Publishing here is
# best-effort — a worktree run on a host without that module enabled
# (or before its first darwin-rebuild switch) shouldn't fail the test run.
REPORTS_DIR="/var/lib/static-reports/${WORKTREE_ID}"

if [ $# -gt 0 ]; then
  echo "Unknown option: $1" >&2
  echo "Usage: $0" >&2
  exit 1
fi

cleanup() {
  # Publish whatever report exists (pass or fail) before tearing the
  # stack down, so a failure is still inspectable afterward - same
  # pattern as skills/project/e2e-test-opencloud/scripts/run.sh.
  if [ -d "$E2E_DIR/test-results/html" ] && mkdir -p "$REPORTS_DIR" 2>/dev/null; then
    rm -rf "${REPORTS_DIR:?}"/*
    cp -r "$E2E_DIR/test-results/html/." "$REPORTS_DIR/"
    echo "[e2e-forgejo] report published: https://reports.$(scutil --get LocalHostName 2>/dev/null || hostname -s).internal/${WORKTREE_ID}/" >&2
  fi
  # teardown, not down: nothing here needs an expensive one-time manual
  # bootstrap worth preserving between runs (unlike tests/e2e's OpenCloud
  # suite) - leftover state would instead just make the next run's
  # `admin user create` fail on a duplicate user. See design.md.
  "$STACK" teardown
}
trap cleanup EXIT

"$STACK" up
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

export FORGEJO_COMPOSE_FILE="$REPO_ROOT/modules/forgejo/compose.yaml"
export FORGEJO_OVERRIDE_COMPOSE_FILE="$E2E_DIR/fixtures/forgejo.override.yaml"
export FORGEJO_ENV_FILE="$ENV_FILE"
export FORGEJO_STATE_DIR="$E2E_DIR/.state"

cd "$E2E_DIR"
if [ ! -d node_modules ]; then
  echo "[e2e-forgejo] installing npm dependencies (first run)..." >&2
  nix develop "$REPO_ROOT#e2e" -c npm install
fi
nix develop "$REPO_ROOT#e2e" -c npx playwright test
