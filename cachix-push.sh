nix build .\#homeConfigurations.mfuruki.activationPackage --json \
  | jq -r '.[].outputs | to_entries[].value' \
  | cachix push ccycle