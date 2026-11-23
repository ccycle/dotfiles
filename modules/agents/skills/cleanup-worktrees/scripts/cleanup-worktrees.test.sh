#!/usr/bin/env bash
# Regression test: an unmerged worktree is refused, and a merged, started, clean worktree that is not open in any
# herdr workspace (open_workspace_id: null) must be removed through git, never
# via `herdr worktree remove --workspace null`.
# Runs against a real temporary git repo; only herdr (needs a live server) and
# tart are stubbed. The stub herdr fails any `remove`, so a regression shows up
# as a failed removal and as a logged herdr remove call.
# Usage: cleanup-worktrees.test.sh
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd -P)"
tmp="$(mktemp -d)"
tmp="$(cd "$tmp" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT
failures=0

check() { # check <name> <command...>
  local name="$1"
  shift
  if "$@"; then echo "ok   $name"; else
    echo "FAIL $name"
    failures=$((failures + 1))
  fi
}

# Isolate git from the user's config (hooks, signing) and give it an identity.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 HOME="$tmp/home"
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid
mkdir -p "$HOME" "$tmp/bin"

cat >"$tmp/bin/herdr" <<'EOF'
#!/bin/sh
echo "herdr $*" >>"$HERDR_LOG"
[ "$2" = list ] && exec cat "$HERDR_JSON"
exit 1
EOF
printf '#!/bin/sh\nexit 0\n' >"$tmp/bin/tart"
chmod +x "$tmp/bin/herdr" "$tmp/bin/tart"
export PATH="$tmp/bin:$PATH" HERDR_LOG="$tmp/herdr.log" HERDR_JSON="$tmp/list.json"

repo="$tmp/repo"
git init -q --bare -b main "$tmp/origin.git"
git init -q -b main "$repo"
git -C "$repo" remote add origin "$tmp/origin.git"
git -C "$repo" commit -q --allow-empty -m init
git -C "$repo" push -q origin main
add_worktree() { # add_worktree <branch>: one commit of work on a new branch off main
  git -C "$repo" worktree add -q -b "$1" "$tmp/$1"
  mkdir -p "$tmp/$1/sub" && touch "$tmp/$1/sub/$1"
  git -C "$tmp/$1" add sub && git -C "$tmp/$1" commit -q -m "work on $1"
}
# Merged only on origin, as a Forgejo merge leaves it: the script must sync local main itself.
add_worktree cleanup-test-single
git -C "$repo" push -q origin cleanup-test-single:main
add_worktree cleanup-test-unmerged
# cleanup-merged-worktrees.sh resolves the repo from its own location.
mkdir "$repo/.scripts" && cp "$here/cleanup-merged-worktrees.sh" "$repo/.scripts/"
echo .scripts >>"$repo/.git/info/exclude"

list_json() { # list_json <branch...>: listed worktrees, none open in herdr
  local b
  printf '{"result":{"worktrees":[{"branch":"main","open_workspace_id":"w1","is_linked_worktree":false,"path":"%s"}' "$repo"
  for b in "$@"; do
    printf ',{"branch":"%s","open_workspace_id":null,"is_linked_worktree":true,"path":"%s"}' "$b" "$tmp/$b"
  done
  printf ']}}\n'
}
has() { grep -qF -- "$2" <<<"$1"; } # has <haystack> <needle>
lacks() { ! has "$@"; }
no_herdr_remove() { ! grep -q 'worktree remove' "$HERDR_LOG" 2>/dev/null; }

# cleanup-worktree.sh: refuses a started but unmerged worktree.
list_json cleanup-test-unmerged >"$HERDR_JSON"
out=$(cd "$tmp/cleanup-test-unmerged" && "$here/cleanup-worktree.sh" --force 2>&1)
check "unmerged --force refuses" has "$out" "NOT MERGED (branch is not an ancestor of main)"
check "unmerged worktree kept" test -d "$tmp/cleanup-test-unmerged"

# cleanup-worktree.sh: removes the current worktree, even when run from a
# subdirectory of it.
list_json cleanup-test-single >"$HERDR_JSON"
out=$(cd "$tmp/cleanup-test-single/sub" && "$here/cleanup-worktree.sh" --dry-run 2>&1)
check "single finds worktree from a subdirectory" has "$out" "SAFE (started, merged to main, clean)"
check "single dry-run shows no 'null' workspace" lacks "$out" null
out=$(cd "$tmp/cleanup-test-single/sub" && "$here/cleanup-worktree.sh" --force 2>&1)
check "single --force succeeds" has "$out" "Removed worktree for cleanup-test-single"
check "single worktree removed" test ! -e "$tmp/cleanup-test-single"
check "single did not call herdr remove" no_herdr_remove

# cleanup-merged-worktrees.sh: scans all worktrees; it does not sync main, so merge locally.
add_worktree cleanup-test-merged
git -C "$repo" merge -q --ff-only cleanup-test-merged
list_json cleanup-test-merged >"$HERDR_JSON"
out=$("$repo/.scripts/cleanup-merged-worktrees.sh" --dry-run 2>&1)
check "merged dry-run lists candidate" has "$out" "Would remove worktree for cleanup-test-merged"
check "merged dry-run shows no 'null' workspace" lacks "$out" null
out=$("$repo/.scripts/cleanup-merged-worktrees.sh" --force 2>&1)
check "merged --force succeeds" has "$out" "Removed worktree for cleanup-test-merged"
check "merged worktree removed" test ! -e "$tmp/cleanup-test-merged"
check "merged did not call herdr remove" no_herdr_remove

check "branches are kept" git -C "$repo" show-ref -q --verify refs/heads/cleanup-test-single refs/heads/cleanup-test-merged

if [ "$failures" -ne 0 ]; then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
