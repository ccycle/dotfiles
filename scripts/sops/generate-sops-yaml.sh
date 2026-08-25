#!/usr/bin/env bash
# Regenerate the committed .sops.yaml from the age-keys.nix ledger.
#   scripts/sops/generate-sops-yaml.sh
# The ledger (modules/sops/age-keys.nix) is the single source of truth for
# which keys may decrypt which secret files.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

cd "${REPO_ROOT}"

LEDGER_JSON="$(nix eval --json --impure --expr 'import ./modules/sops/age-keys.nix')"

cat >.sops.yaml <<EOF
$(echo "${LEDGER_JSON}" | jq -r '
  [ "creation_rules:",
    ( [ .rules[] as $r
        | .hosts as $H
        | [ "  - path_regex: " + $r.path_regex,
            "    key_groups:",
            "      - age:",
            (($r.hosts | map($H[.])) + .transitionKeys
              | map("          - " + .) | join("\n"))
          ] | join("\n")
      ] | join("\n") )
  ] | join("\n")
')
EOF

echo "Regenerated .sops.yaml from modules/sops/age-keys.nix"
echo "Run 'sops updatekeys -y <file>' to re-encrypt any changed secret file."
