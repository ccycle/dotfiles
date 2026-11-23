#!/usr/bin/env bash
set -uo pipefail

usage="usage: secret-rotate.test.sh [bws-project-id holding the BWS_SMOKE_TEST fixture]"
bws_project="${1:-}"
src="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
real_rbw="$(command -v rbw)" || {
  echo "rbw not on PATH; $usage" >&2
  exit 1
}
failures=0

check() {
  if eval "$2"; then
    echo "ok   $1"
  else
    echo "FAIL $1"
    failures=$((failures + 1))
  fi
}

repo="$(mktemp -d)"
trap 'rm -rf "$repo"' EXIT
mkdir -p "$repo/bin" "$repo/modules/sops" "$repo/modules/demo" "$repo/.agents/skills/credentials-manager/scripts" "$repo/modules/agents/skills/bws/scripts"
for f in secret-rotate.sh sops-with-rbw check-recipients.sh; do
  cp "$src/.agents/skills/credentials-manager/scripts/$f" "$repo/.agents/skills/credentials-manager/scripts/"
done
cp "$src/modules/agents/skills/bws/scripts/bws-agent" "$repo/modules/agents/skills/bws/scripts/"

key="$repo/bin/dummy-age-key.txt"
age-keygen -o "$key" 2>/dev/null
pub="$(age-keygen -y "$key")"
cat >"$repo/bin/rbw" <<EOF
#!/usr/bin/env bash
if [ "\$1 \$2" = "get dummy-age-key" ]; then exec cat "$key"; fi
exec "$real_rbw" "\$@"
EOF
chmod +x "$repo/bin/rbw"
cat >"$repo/modules/sops/age-keys.nix" <<EOF
{ hosts.demo = "$pub"; transitionKeys = [ ]; rules = [ { path_regex = "modules/demo/secrets.yaml\$"; hosts = [ "demo" ]; } ]; }
EOF
file=modules/demo/secrets.yaml
printf 'rotated: DUMMY-OLD-7f3a\nother: DUMMY-OTHER-c41e\nnested:\n  inner: DUMMY-NESTED-02bd\n' >"$repo/$file"
(cd "$repo" && SOPS_AGE_KEY_FILE="$key" sops -e -i --age "$pub" "$file") || exit 1
git -C "$repo" init -q
git -C "$repo" config user.name test
git -C "$repo" config user.email test@invalid
git -C "$repo" config commit.gpgsign false
git -C "$repo" add -A
git -C "$repo" commit -qm init

export PATH="$repo/bin:$PATH" RBW_ITEM_NAME=dummy-age-key
rotate="$repo/.agents/skills/credentials-manager/scripts/secret-rotate.sh"
decrypt() { SOPS_AGE_KEY_FILE="$key" sops -d --extract "$1" "$repo/$file"; }
leaks() { grep -qE 'DUMMY-(OLD|OTHER|NESTED|NEW)' <<<"$1"; }

out="$("$rotate" "$file" 2>&1)"
rc=$?
check "incident: whole-file editor mode is refused" '[ "$rc" -ne 0 ] && [ "$(git -C "$repo" rev-list --count HEAD)" = 1 ]'
out="$("$rotate" --key rotated --value DUMMY-NEW-argv --no-rebuild "$file" 2>&1)"
rc=$?
check "value on argv is refused" '[ "$rc" -ne 0 ] && [ "$(decrypt "[\"rotated\"]")" = DUMMY-OLD-7f3a ]'

out="$(printf 'DUMMY-NEW-PROMPT-91c2\n' | "$rotate" --key rotated --from-prompt --no-rebuild "$file" 2>&1)"
rc=$?
check "prompt: rotation succeeds" '[ "$rc" -eq 0 ]'
check "prompt: target key replaced" '[ "$(decrypt "[\"rotated\"]")" = DUMMY-NEW-PROMPT-91c2 ]'
check "prompt: other keys untouched" '[ "$(decrypt "[\"other\"]")" = DUMMY-OTHER-c41e ] && [ "$(decrypt "[\"nested\"][\"inner\"]")" = DUMMY-NESTED-02bd ]'
check "prompt: output shows no secret value" '! leaks "$out"'
check "prompt: committed" '[ "$(git -C "$repo" log -1 --format=%s)" = "rotate(secrets): $file key=rotated" ]'

out="$(printf 'DUMMY-NEW-NESTED-5e77\n' | "$rotate" --key nested.inner --from-prompt --no-rebuild "$file" 2>&1)"
rc=$?
check "prompt: dotted key path reaches nested key" '[ "$(decrypt "[\"nested\"][\"inner\"]")" = DUMMY-NEW-NESTED-5e77 ] && ! leaks "$out"'

if [ -z "$bws_project" ]; then
  echo "skip bws case: no project id given ($usage)"
else
  out="$("$rotate" --key rotated --from-bws "$bws_project" BWS_SMOKE_TEST --no-rebuild "$file" 2>&1)"
  rc=$?
  check "bws: rotation succeeds" '[ "$rc" -eq 0 ]'
  check "bws: output shows no secret value" '! leaks "$out"'
  match="$("$repo/modules/agents/skills/bws/scripts/bws-agent" run "$bws_project" -- \
    "[ \"\$(SOPS_AGE_KEY_FILE='$key' sops -d --extract '[\"rotated\"]' '$repo/$file')\" = \"\$BWS_SMOKE_TEST\" ] && echo same")"
  check "bws: target key equals the bws value" '[ "$match" = same ]'
  check "bws: other keys untouched" '[ "$(decrypt "[\"other\"]")" = DUMMY-OTHER-c41e ]'
fi

[ "$failures" -eq 0 ] || {
  echo "$failures failure(s)"
  exit 1
}
echo "all passed"
