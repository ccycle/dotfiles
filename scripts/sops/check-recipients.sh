#!/usr/bin/env bash
# Verify that every secrets*.yaml file's actual sops recipients match the
# per-machine key rules declared in modules/sops/age-keys.nix.
#
# The recipient list of an encrypted file is stored in plaintext in its
# trailing `sops:` metadata block, so this check needs no decryption keys.
# Allowed recipients per file = (keys of hosts matched by the first path
# rule) + transitionKeys; anything outside that set is a drift violation.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${REPO_ROOT}"

LEDGER="$(nix eval --json --impure --expr 'import ./modules/sops/age-keys.nix')"

readarray -t FILES < <(git ls-files -z '**' 2>/dev/null | tr '\0' '\n' | grep -E '(^|/)secrets[^/]*\.yaml$' | grep -v '^\.local/' || true)

expect() {
  jq -rn --arg path "$1" --argjson ledger "$LEDGER" '
    [ $ledger.rules[] as $r
      | select(($path | test($r.path_regex)))
      | [ $r.hosts[] as $h | $ledger.hosts[$h] ] + $ledger.transitionKeys
    ]
    | (first // [])
    | unique | sort | join("\n")
  '
}

fail=0
for file in "${FILES[@]}"; do
  [ -f "${file}" ] || continue

  expected="$(expect "${file}" 2>/dev/null || true)"
  actual="$(sed -n '/^sops:/,$p' "${file}" | grep -oE 'age1[a-z0-9]+' | sort -u)"

  if [ -z "$expected" ]; then
    echo "❌ ${file}: no matching path_regex rule in modules/sops/age-keys.nix"
    fail=1
  elif [ "$actual" != "$expected" ]; then
    echo "❌ ${file}: recipient drift"
    echo "   actual:   $(echo "$actual" | tr '\n' ' ')"
    echo "   expected: $(echo "$expected" | tr '\n' ' ')"
    echo "   → run scripts/sops/generate-sops-yaml.sh, then 'sops updatekeys -y ${file}'"
    fail=1
  else
    echo "✅ ${file}"
  fi
done

if [ "$fail" -ne 0 ]; then
  echo "Recipient check failed."
  exit 1
fi
echo "✅ Recipient check passed."
