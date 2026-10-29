#!/usr/bin/env bash
# Integration test for bws-agent against the real rbw and Bitwarden Secrets Manager.
# Requires an unlocked rbw and a project readable by the agent machine account
# that holds two dummy fixtures:
#   BWS_SMOKE_TEST   any non-empty value
#   BWS_SMOKE_SPECIAL_CHARS  a value with characters special to regexes (e.g. `a.b*c[d]+e`),
#                            so a redactor that stops escaping values fails the test
# Only these fixtures are ever expanded inside `run`, so a broken redactor can
# print dummy values but never another secret in the project.
# Usage: bws-agent.test.sh <project-name>
set -uo pipefail

project_name="${1:?usage: bws-agent.test.sh <project-name>}"
agent="$(dirname "$0")/bws-agent"
failures=0

check() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "ok   $name"
  else
    echo "FAIL $name: expected [$expected], got [$actual]"
    failures=$((failures + 1))
  fi
}

# Refusals: argument validation runs before rbw, so these need no network.
for args in "secret get x" "secret list p" "project get x" "keys" "run p echo hi" ""; do
  # shellcheck disable=SC2086 # word splitting of $args is intended
  "$agent" $args >/dev/null 2>&1
  check "refuses '${args}'" 2 "$?"
done

rbw unlocked >/dev/null 2>&1 || {
  echo "rbw is locked; run 'rbw unlock' first" >&2
  exit 1
}

project_id="$("$agent" project list | awk -v n="$project_name" '$2 == n { print $1 }')"
[ -n "$project_id" ] || {
  echo "project '$project_name' not visible to the machine account" >&2
  exit 1
}
echo "ok   project list finds '$project_name'"

keys="$("$agent" keys "$project_id")"
check "keys lists BWS_SMOKE_TEST" yes "$(grep -qx BWS_SMOKE_TEST <<<"$keys" && echo yes || echo no)"
check "keys lists BWS_SMOKE_SPECIAL_CHARS" yes "$(grep -qx BWS_SMOKE_SPECIAL_CHARS <<<"$keys" && echo yes || echo no)"
check "keys prints only key names" "" "$(grep -vE '^[A-Za-z_][A-Za-z0-9_]*$' <<<"$keys")"

# One run covers injection, redaction on both streams, special characters and the token.
# shellcheck disable=SC2016 # expanded by the child shell, not here
out="$("$agent" run "$project_id" -- '
  test -n "$BWS_SMOKE_TEST" && echo injected
  echo "out:$BWS_SMOKE_TEST"
  echo "err:$BWS_SMOKE_TEST" >&2
  case "$BWS_SMOKE_SPECIAL_CHARS" in *[.*+?\[\(\|]*) echo "special:$BWS_SMOKE_SPECIAL_CHARS" ;; *) echo special:none-in-fixture ;; esac
  test -z "${BWS_ACCESS_TOKEN:-}" && echo token-absent || echo token-present
')"
check "run injects secrets" yes "$(grep -qx injected <<<"$out" && echo yes || echo no)"
check "run redacts stdout" "out:[REDACTED]" "$(grep '^out:' <<<"$out")"
check "run redacts stderr" "err:[REDACTED]" "$(grep '^err:' <<<"$out")"
check "run redacts values containing special characters" "special:[REDACTED]" "$(grep '^special:' <<<"$out")"
check "run hides token from child" token-absent "$(grep '^token-' <<<"$out")"

"$agent" run "$project_id" -- 'exit 7' >/dev/null 2>&1
check "run passes exit code through" 7 "$?"

if [ "$failures" -ne 0 ]; then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
