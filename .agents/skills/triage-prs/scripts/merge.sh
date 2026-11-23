#!/usr/bin/env bash
set -euo pipefail

n="${1:?usage: merge.sh <pr-number>}"
here="$(cd "$(dirname "$0")" && pwd)"
host=forgejo.mac-mini-m4-pro.internal
api="https://$host/api/v1/repos/ccycle/dotfiles"
keys="$HOME/Library/Application Support/Cyborus.forgejo-cli/keys.json"

die() {
  echo "refusing to merge #$n: $*" >&2
  exit 1
}

pr="$(curl -fsS "$api/pulls/$n")"
[ "$(jq -r .merged <<<"$pr")" = false ] || die "already merged"
[ "$(jq -r .state <<<"$pr")" = open ] || die "not open"
sha="$(jq -r .head.sha <<<"$pr")"

git fetch -q origin
git merge-base --is-ancestor origin/main "$sha" || die "head $sha is not on top of origin/main; delegate a rebase"
for c in $(git rev-list "origin/main..$sha"); do
  git verify-commit "$c" 2>/dev/null || die "commit $c is not signed by a trusted key"
done
"$here/ci-state.sh" "$sha" >/dev/null 2>&1 || die "CI on $sha is not green; run ci-state.sh $sha"

token="$(jq -r --arg h "$host" '.hosts[$h].token // empty' "$keys")"
[ -n "$token" ] || die "no fj token for $host in $keys; run fj auth login"
body="$(mktemp)"
trap 'rm -f "$body"' EXIT
code="$(printf 'header = "Authorization: token %s"\n' "$token" |
  curl -sS -K - -o "$body" -w '%{http_code}' -X POST -H 'Content-Type: application/json' \
    -d "{\"Do\":\"fast-forward-only\",\"head_commit_id\":\"$sha\"}" "$api/pulls/$n/merge")"
[ "$code" = 200 ] || die "Forgejo answered HTTP $code: $(cat "$body")"
[ "$(curl -fsS "$api/pulls/$n" | jq -r .merged)" = true ] || die "Forgejo accepted the merge but the PR is not merged"
echo "merged #$n at $sha"
