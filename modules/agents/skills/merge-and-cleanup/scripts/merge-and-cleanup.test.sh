#!/usr/bin/env bash
# Precondition and PR-state dispatch checks for merge-and-cleanup.sh.
# Runs in a temporary git repo; curl (the Forgejo pulls API), fj, and herdr are stubbed so nothing is pushed, opened, or removed.
# Usage: merge-and-cleanup.test.sh
set -uo pipefail

script="$(cd "$(dirname "$0")" && pwd -P)/merge-and-cleanup.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
failures=0

check() { # check <name> <expected exit> <expected output substring> <args...>
  local name=$1 code=$2 want=$3 out rc
  shift 3
  out=$(cd "$tmp/repo" && "$script" "$@" 2>&1)
  rc=$?
  if [ "$rc" = "$code" ] && [[ $out == *"$want"* ]]; then echo "ok   $name"; else
    printf 'FAIL %s (exit %s)\n%s\n' "$name" "$rc" "$out"
    failures=$((failures + 1))
  fi
}

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 HOME="$tmp/home"
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid
mkdir -p "$HOME" "$tmp/bin"
# shellcheck disable=SC2016 # stub bodies expand at stub run time
printf '#!/bin/sh\ncat "$PULLS_JSON"\n' >"$tmp/bin/curl"
# shellcheck disable=SC2016
printf '#!/bin/sh\necho "unexpected $(basename "$0") $*" >&2\nexit 1\n' >"$tmp/bin/fj"
cp "$tmp/bin/fj" "$tmp/bin/herdr"
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH" PULLS_JSON="$tmp/pulls.json" HERDR_ENV=1

git init -q -b main "$tmp/repo"
git -C "$tmp/repo" commit -q --allow-empty -m init
git -C "$tmp/repo" remote add origin https://forgejo.example.invalid/owner/repo.git
git -C "$tmp/repo" checkout -q -b feat

pulls() { printf '[{"number":9,"state":"%s","merged":%s,"head":{"label":"%s"},"html_url":"https://x/pulls/9"}]' "$@" >"$PULLS_JSON"; }

check "help" 0 "Usage:" --help
check "unknown arg" 1 "unknown argument" --bogus
HERDR_ENV=0 check "outside herdr" 1 "not running inside Herdr"
pulls open false feat
check "open PR stops" 0 "PR #9 is open"
check "--remove refused while open" 1 "--remove applies only once the PR is merged" --remove
pulls closed false feat
check "closed unmerged fails" 1 "closed without merging"
pulls open false other-branch
check "--remove refused without PR" 1 "PR state: none" --remove
touch "$tmp/repo/dirty"
check "dirty tree refused" 1 "uncommitted changes"
rm "$tmp/repo/dirty"
git -C "$tmp/repo" checkout -q main
check "main refused" 1 "on main"

[ "$failures" -eq 0 ] || exit 1
