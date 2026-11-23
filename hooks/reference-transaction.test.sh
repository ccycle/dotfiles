#!/usr/bin/env bash
set -uo pipefail

hooks="$(cd "$(dirname "$0")" && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
failures=0
check() {
  local name="$1"
  shift
  if "$@"; then echo "ok   $name"; else
    echo "FAIL $name"
    failures=$((failures + 1))
  fi
}

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid

repo() {
  local storage="$1" origin="$2"
  case "$storage" in loose | packed | both) ;; *)
    echo "repo: unknown main storage '$storage' (loose|packed|both)" >&2
    exit 2
    ;;
  esac
  case "$origin" in equal | behind) ;; *)
    echo "repo: unknown origin state '$origin' (equal|behind)" >&2
    exit 2
    ;;
  esac
  r="$tmp/r$((++n))"
  git init -q -b main "$r"
  git -C "$r" commit -q --allow-empty -m init
  git -C "$r" switch -q -c other
  main_oid=$(git -C "$r" rev-parse main)
  git -C "$r" update-ref refs/remotes/origin/main main
  if [ "$origin" = behind ]; then
    git -C "$r" commit -q --allow-empty -m upstream
    git -C "$r" update-ref refs/remotes/origin/main other
  fi
  case "$storage" in
  packed) git -C "$r" pack-refs --all ;;
  both)
    git -C "$r" pack-refs --all
    echo "$main_oid" >"$r/.git/refs/heads/main"
    ;;
  esac
  git -C "$r" config core.hooksPath "$hooks"
}
main_intact() { [ "$(git -C "$r" rev-parse --verify --quiet main)" = "$main_oid" ]; }
rejected() { ! git -C "$r" "$@" >/dev/null 2>&1 && main_intact; }

n=0
for origin in equal behind; do
  for st in loose packed both; do
    c="[$st, main $origin]"
    repo "$st" "$origin"
    check "$c pack-refs --all succeeds" git -C "$r" pack-refs --all
    check "$c pack-refs keeps main" main_intact
    check "$c pack-refs leaves no loose main" test ! -e "$r/.git/refs/heads/main"

    repo "$st" "$origin"
    check "$c branch -D main is rejected" rejected branch -D main
    repo "$st" "$origin"
    check "$c update-ref -d main is rejected" rejected update-ref -d refs/heads/main
    repo "$st" "$origin"
    check "$c update-ref -d main <old> is rejected" rejected update-ref -d refs/heads/main "$main_oid"
  done

  repo loose "$origin"
  git -C "$r" switch -q main
  check "[main $origin] direct commit on main is rejected" rejected commit -q --allow-empty -m direct
  check "[main $origin] reset of main to a local commit is rejected" \
    rejected reset -q --hard "$(git -C "$r" commit-tree -m local "main^{tree}")"
done

repo loose behind
git -C "$r" worktree add -q --detach "$tmp/linked"
check "[linked worktree] pack-refs --all succeeds" git -C "$tmp/linked" pack-refs --all
check "[linked worktree] pack-refs keeps main" main_intact
check "[linked worktree] update-ref -d main <old> is rejected" bash -c '
  ! git -C "$0" update-ref -d refs/heads/main "$1" >/dev/null 2>&1' "$tmp/linked" "$main_oid"
check "[linked worktree] main survives the deletion attempt" main_intact

repo packed behind
check "fast-forward of main to origin/main is allowed" git -C "$r" update-ref refs/heads/main origin/main
repo packed behind
git -C "$r" switch -q main
check "merge --ff-only origin/main on main is allowed" git -C "$r" merge -q --ff-only origin/main

[ "$failures" -eq 0 ] && echo "all passed" || {
  echo "$failures failed"
  exit 1
}
