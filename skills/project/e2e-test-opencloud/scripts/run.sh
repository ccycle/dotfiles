#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH='' cd -- "$(dirname -- "$0")/../../../.." && pwd)"
e2e_dir="$repo_root/tests/e2e"
stack="$e2e_dir/scripts/stack.sh"
worktree_id="$(basename "$repo_root")"
# modules/static-reports/options.nix's default dataDir. Publishing here is
# best-effort — a worktree run on a host without that module enabled
# (or before its first darwin-rebuild switch) shouldn't fail the test run.
reports_dir="/var/lib/static-reports/${worktree_id}"

if [ $# -gt 0 ]; then
  echo "Unknown option: $1" >&2
  echo "Usage: $0" >&2
  exit 1
fi

cleanup() {
  # Publish whatever report exists (pass or fail) before tearing the
  # stack down, so a failure is still inspectable afterward.
  if [ -d "$e2e_dir/test-results/html" ] && mkdir -p "$reports_dir" 2>/dev/null; then
    rm -rf "${reports_dir:?}"/*
    cp -r "$e2e_dir/test-results/html/." "$reports_dir/"
    echo "[e2e] report published: https://reports.$(scutil --get LocalHostName 2>/dev/null || hostname -s).internal/${worktree_id}/" >&2
  fi
  "$stack" down
}
trap cleanup EXIT

"$stack" up

# shellcheck disable=SC1091
source "$e2e_dir/.state/env-for-playwright.sh"

cd "$e2e_dir"

# First run in a new worktree: node_modules isn't checked in, and without
# it `npx playwright test` silently fetches a standalone `playwright`
# package into npx's own cache instead of using this project's pinned
# `@playwright/test` — playwright.config.ts then fails to resolve that
# import. Installing once from the committed lockfile fixes it for good.
if [ ! -d node_modules ]; then
  echo "[e2e] installing Playwright test dependencies (first run in this worktree)..." >&2
  nix develop "$repo_root#e2e" -c npm ci
fi

nix develop "$repo_root#e2e" -c npx playwright test
