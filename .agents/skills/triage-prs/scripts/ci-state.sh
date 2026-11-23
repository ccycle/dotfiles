#!/usr/bin/env bash
set -euo pipefail

usage="usage: ci-state.sh <commit-sha> [--wait <timeout-seconds>]"
[ $# -eq 1 ] || { [ $# -eq 3 ] && [ "$2" = --wait ] && [[ $3 =~ ^[0-9]+$ ]]; } || {
  echo "$usage" >&2
  exit 2
}
sha="$1"
timeout="${3:-}"
here="$(cd "$(dirname "$0")" && pwd)"
api=https://forgejo.mac-mini-m4-pro.internal/api/v1/repos/ccycle/dotfiles

git cat-file -e "$sha^{commit}" 2>/dev/null || {
  echo "error: commit $sha is not in the local repo; run git fetch origin" >&2
  exit 2
}
expected="$(
  git ls-tree --name-only "$sha" .forgejo/workflows/ | while read -r f; do
    git show "$sha:$f" | yq -r --from-file "$here/expected-contexts.yq"
  done | jq -Rsc 'split("\n") | map(select(. != ""))'
)"

start=$SECONDS
while :; do
  status="$(curl -fsS "$api/commits/$sha/status")"
  state="$(jq -r --argjson expected "$expected" -f "$here/ci-state.jq" <<<"$status")"
  if [ "$state" != pending ] || [ -z "$timeout" ] || [ $((SECONDS - start)) -ge "$timeout" ]; then
    break
  fi
  sleep 20
done
jq -r '(.statuses // [])[] | "\(.status)\t\(.context)"' <<<"$status" >&2
echo "$state"
case "$state" in
success) exit 0 ;;
failure) exit 1 ;;
*) exit 3 ;;
esac
