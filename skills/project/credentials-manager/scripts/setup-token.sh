#!/usr/bin/env bash
set -e

TOKEN_VAR="$1"

if [ -z "$TOKEN_VAR" ]; then
  echo "Usage: $0 <token_variable_name>"
  echo "Example: $0 github_pat_work"
  exit 1
fi

cat <<EOF
# Copy and paste the following configuration into your modules/darwin.nix

{ config, ... }:
{
  sops.templates."nix-access-tokens-work.conf" = {
    content = ''
      access-tokens = github.com=\${config.sops.placeholder.${TOKEN_VAR}}
    '';
    path = "/etc/nix/nix-access-tokens-work.conf";
  };

  nix.extraOptions = ''
    !include \${config.sops.templates."nix-access-tokens-work.conf".path}
  '';
}
EOF
