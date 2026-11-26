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

git init -q --bare -b main "$tmp/remote.git"
git init -q -b main "$tmp/seed"
git -C "$tmp/seed" commit -q --allow-empty -m init
git -C "$tmp/seed" push -q "$tmp/remote.git" main

git clone -q "$tmp/remote.git" "$tmp/r"
r="$tmp/r"
mkdir "$tmp/hooks"
ln -s "$hooks/pre-push" "$tmp/hooks/pre-push"
git -C "$r" config core.hooksPath "$tmp/hooks"
git -C "$r" switch -q -c feature
git -C "$r" commit -q --allow-empty -m feature
remote_main=$(git -C "$tmp/remote.git" rev-parse main)

remote_main_intact() { [ "$(git -C "$tmp/remote.git" rev-parse main)" = "$remote_main" ]; }
rejected() { ! git -C "$r" push -q "$@" >/dev/null 2>&1 && remote_main_intact; }

check "push feature branch is allowed" git -C "$r" push -q origin feature
check "push feature:main is rejected" rejected origin feature:main
check "push HEAD:refs/heads/main is rejected" rejected origin HEAD:refs/heads/main
git -C "$r" switch -q main
git -C "$r" merge -q --ff-only feature
check "push main from main is rejected" rejected origin main
check "push --force main is rejected" rejected --force origin main
check "deleting remote main is rejected" rejected origin :main
check "push main among other refs is rejected" rejected origin feature main
check "error names the Forgejo PR path" bash -c '
  git -C "$0" push origin main 2>&1 | grep -q "merged Forgejo PR"' "$r"

[ "$failures" -eq 0 ] && echo "all passed" || {
  echo "$failures failed"
  exit 1
}
