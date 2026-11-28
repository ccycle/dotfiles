#!/usr/bin/env bash
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
url=https://forge.invalid/o/r.git
failures=0

check() {
  if [ "$2" = "$3" ]; then
    echo "ok   $1"
  else
    echo "FAIL $1: expected [$3], got [$2]"
    failures=$((failures + 1))
  fi
}

mkdir "$tmp/bin"
cat >"$tmp/bin/curl" <<EOF
#!/usr/bin/env bash
case "\$*" in
*/pulls/7*) printf '{"state":"%s","merged":%s,"head":{"sha":"%s","ref":"feature"},"base":{"ref":"main"}}' \
  "\$(cat "$tmp/pr-state")" "\$(cat "$tmp/pr-merged")" "\$(git --git-dir="$tmp/remote.git" rev-parse feature)" ;;
*/actions/runs*) printf '{"workflow_runs":[{"id":1,"status":"%s","workflow_id":"verify.yaml","html_url":"u"}]}' "\$(cat "$tmp/ci")" ;;
*) exit 22 ;;
esac
EOF
chmod +x "$tmp/bin/curl"

commit() {
  printf '%s\n' "$3" >>"$1/$2" && git -C "$1" add "$2" && git -C "$1" commit -qm "$2"
}

setup() {
  local main_file="$1" main_line="$2" feature_file="$3" feature_line="$4"
  rm -rf "$tmp/remote.git" "$tmp/main" "$tmp/feature"
  echo open >"$tmp/pr-state" && echo false >"$tmp/pr-merged" && echo success >"$tmp/ci"
  git init -q --bare -b main "$tmp/remote.git"
  git init -q -b main "$tmp/main"
  git -C "$tmp/main" config user.name test
  git -C "$tmp/main" config user.email test@invalid
  git -C "$tmp/main" config url."$tmp/remote.git".insteadOf "$url"
  git -C "$tmp/main" remote add origin "$url"
  commit "$tmp/main" shared base
  git -C "$tmp/main" worktree add -q -b feature "$tmp/feature" main
  commit "$tmp/feature" "$feature_file" "$feature_line"
  git -C "$tmp/main" push -q origin main feature
  git -C "$tmp/feature" branch -q -u origin/feature
  [ -z "$main_file" ] || { commit "$tmp/main" "$main_file" "$main_line" && git -C "$tmp/main" push -q origin main; }
}

run() { (cd "$tmp/feature" && PATH="$tmp/bin:$PATH" "$here/mergeable.sh" origin 7 "${1:-true}" 2>"$tmp/err"); }
on_main() { git --git-dir="$tmp/remote.git" merge-base --is-ancestor main feature && echo yes || echo no; }

setup "" "" own feature
before="$(git --git-dir="$tmp/remote.git" rev-parse feature)"
out="$(run)"
check "fast-forwardable and green: exit 0" "$?" 0
check "fast-forwardable and green: verdict" "${out%%:*}" "mergeable (fast-forward)"
check "fast-forwardable: nothing pushed" "$(git --git-dir="$tmp/remote.git" rev-parse feature)" "$before"

echo failure >"$tmp/ci"
out="$(run)"
check "CI failure is not mergeable" "$?:${out%% on*}" "1:not mergeable: CI failed"

echo true >"$tmp/pr-merged"
out="$(run)"
check "merged PR is not mergeable" "$?:$out" "1:not mergeable: PR #7 is already merged"

setup other moved own feature
out="$(run)"
check "outdated, rebases cleanly: exit 0" "$?:${out%%:*}" "0:mergeable (fast-forward)"
check "outdated: pushed on top of main" "$(on_main)" yes

setup shared main-appended shared feature-appended
out="$(run)"
check "both appended to one file: exit 0" "$?:${out%%:*}" "0:mergeable (fast-forward)"
check "both appended to one file: kept both" "$(git --git-dir="$tmp/remote.git" show feature:shared | paste -sd, -)" "base,main-appended,feature-appended"

setup shared moved own feature
sed -i.bak 's/base/feature-edit/' "$tmp/feature/shared" && rm "$tmp/feature/shared.bak"
git -C "$tmp/feature" commit -qam edit && git -C "$tmp/feature" push -q origin feature
before="$(git -C "$tmp/feature" rev-parse HEAD)"
out="$(run)"
check "conflict: verdict names the file" "$?:$out" "1:not mergeable: conflict in shared"
check "conflict: branch left as it was" "$(git -C "$tmp/feature" rev-parse HEAD):$(git -C "$tmp/feature" status --porcelain)" "$before:"
check "conflict: nothing pushed" "$(on_main)" no

setup other moved own feature
out="$(run false)"
check "failed verification is not pushed" "$?:${out%%;*}" "1:not mergeable: verification failed after rebase"
check "failed verification: nothing pushed" "$(on_main)" no

setup other moved own feature
printf '#!/bin/sh\necho "git-ssh-sign-rbw: rbw is locked" >&2\nexit 1\n' >"$tmp/bin/sign" && chmod +x "$tmp/bin/sign"
git -C "$tmp/feature" config commit.gpgsign true
git -C "$tmp/feature" config gpg.format ssh
git -C "$tmp/feature" config user.signingkey "ssh-ed25519 AAAA"
git -C "$tmp/feature" config gpg.ssh.program "$tmp/bin/sign"
out="$(run)"
check "signing failure is a blocker naming rbw" "$?:$out" "3:blocked: rebase stopped without a conflict: error: git-ssh-sign-rbw: rbw is locked"
check "signing failure: nothing pushed" "$(on_main)" no

echo dirty >>"$tmp/feature/own"
check "rebase-push.sh refuses uncommitted changes" \
  "$("$here/rebase-push.sh" "$tmp/feature" origin main true 2>/dev/null)" "uncommitted changes in $tmp/feature"

"$here/mergeable.sh" origin 7 >/dev/null 2>&1
check "mergeable.sh rejects a missing verify command" "$?" 2

exit "$failures"
