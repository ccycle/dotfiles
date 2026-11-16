#!/usr/bin/env bash
# Print the co-located test suites affected by the current change, one
# scripts/run.sh path per line; with --run, execute them in turn.
#
#   select-tests.sh [--run] [base-ref]   (base-ref defaults to origin/main)
#
# A suite lives at modules/<feature...>/tests/<name>/scripts/run.sh and is
# owned by the directory above tests/. Because a feature's dependencies are
# its children (conventions.md §3), a suite is affected exactly when a changed
# file lies under its owner. A change under a shared path from rules.nix
# (crossHierarchyAllowed, sharedPaths) may reach any feature, and suites run
# inside the flake's devShells, so either of those or flake.nix/flake.lock
# selects every suite. The changed set is the merge-base diff plus uncommitted and
# untracked files, so it works both before and after committing.
set -euo pipefail

REPO_ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
cd "${REPO_ROOT}"

run=0
if [ "${1:-}" = "--run" ]; then
  run=1
  shift
fi
base="${1:-origin/main}"

changed=$(
  {
    git diff --name-only "$(git merge-base "$base" HEAD)"
    git ls-files --others --exclude-standard
  } | sort -u
)
suites=$(git ls-files 'modules/**/tests/*/scripts/run.sh' | sort)
shared=$(nix eval --raw --impure --expr '
  let r = import ./.agents/skills/verify-change/scripts/package-by-feature/rules.nix;
  in builtins.concatStringsSep "\n" (r.crossHierarchyAllowed ++ r.sharedPaths)')
shared+=$'\nflake.nix\nflake.lock'

under() { # under <path> <dir>
  [ "$1" = "$2" ] || [ "${1#"$2"/}" != "$1" ]
}

all=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  while IFS= read -r s; do
    if under "$f" "$s"; then
      all=1
      break 2
    fi
  done <<<"$shared"
done <<<"$changed"

selected=()
while IFS= read -r suite; do
  [ -z "$suite" ] && continue
  owner="${suite%%/tests/*}"
  hit=$all
  if [ "$hit" -eq 0 ]; then
    while IFS= read -r f; do
      if [ -n "$f" ] && under "$f" "$owner"; then
        hit=1
        break
      fi
    done <<<"$changed"
  fi
  [ "$hit" -eq 1 ] && selected+=("$suite")
done <<<"$suites"

for suite in ${selected[@]+"${selected[@]}"}; do
  echo "$suite"
done
if [ "$run" -eq 1 ]; then
  for suite in ${selected[@]+"${selected[@]}"}; do
    echo "=== ▶ $suite ===" >&2
    "./$suite"
  done
fi
