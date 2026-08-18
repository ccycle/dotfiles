{ inputs, pkgs, ... }:
{
  # Push-only token for smoke-test-attic's write→read round-trip check.
  # See skills/project/attic-credentials/SKILL.md for how it's issued.
  sops.secrets.attic-smoke-token = {
    sopsFile = ./secrets.yaml;
  };

  home.packages = [ inputs.attic.packages.${pkgs.stdenv.hostPlatform.system}.default ];
}
