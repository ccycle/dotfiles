#!/usr/bin/env bash
# Orchestrates the Immich E2E suite: brings up the isolated stack
# (scripts/stack.sh), runs the Playwright spec against it, publishes the
# HTML+trace report, then tears the stack down. See
# tests/e2e-immich/design.md for the full rationale.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
E2E_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$E2E_DIR/../.." && pwd)"
STACK="$SCRIPT_DIR/stack.sh"
ENV_FILE="$E2E_DIR/.env"
BRANCH_SLUG="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD | tr '/' '-')"
SERVICE_NAME="immich"
# modules/static-reports/options.nix's default dataDir. Publishing here is
# best-effort — a worktree run on a host without that module enabled
# (or before its first darwin-rebuild switch) shouldn't fail the test run.
REPORTS_BASE_DIR="/var/lib/static-reports"
REPORTS_DIR="$REPORTS_BASE_DIR/${BRANCH_SLUG}/${SERVICE_NAME}"
# Reports are keyed by branch, not worktree, so a stale report survives
# after its worktree is cleaned up - prune anything untouched this long.
REPORTS_RETENTION_DAYS=14

if [ $# -gt 0 ]; then
  echo "Unknown option: $1" >&2
  echo "Usage: $0" >&2
  exit 1
fi

cleanup() {
  # Publish whatever report exists (pass or fail) before tearing the
  # stack down, so a failure is still inspectable afterward - same
  # pattern as tests/e2e-forgejo/scripts/run.sh.
  if [ -d "$E2E_DIR/test-results/html" ] && mkdir -p "$REPORTS_DIR" 2>/dev/null; then
    rm -rf "${REPORTS_DIR:?}"/*
    cp -r "$E2E_DIR/test-results/html/." "$REPORTS_DIR/"
    echo "[e2e-immich] report published: https://reports.$(scutil --get LocalHostName 2>/dev/null || hostname -s).internal/${BRANCH_SLUG}/${SERVICE_NAME}/" >&2
  fi
  # Prune service report dirs untouched past the retention window, then
  # any branch dir left empty by that - best-effort, same rationale as
  # the publish step above.
  if [ -d "$REPORTS_BASE_DIR" ]; then
    find "$REPORTS_BASE_DIR" -mindepth 2 -maxdepth 2 -type d -mtime "+${REPORTS_RETENTION_DAYS}" -exec rm -rf {} + 2>/dev/null || true
    find "$REPORTS_BASE_DIR" -mindepth 1 -maxdepth 1 -type d -empty -exec rmdir {} + 2>/dev/null || true
  fi
  # teardown, not down: nothing here needs a one-time manual bootstrap
  # worth preserving between runs (local admin sign-up is fully
  # API-automated) - leftover state would instead just make the next
  # run's admin-sign-up fail (only the first-ever admin can be created
  # that way). See design.md.
  "$STACK" teardown
}
trap cleanup EXIT

"$STACK" up
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

cd "$E2E_DIR"
if [ ! -d node_modules ]; then
  echo "[e2e-immich] installing npm dependencies (first run)..." >&2
  nix develop "$REPO_ROOT#e2e" -c npm install
fi
nix develop "$REPO_ROOT#e2e" -c npx playwright test
