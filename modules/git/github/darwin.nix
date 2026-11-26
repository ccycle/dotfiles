{ config, ... }:

{
  imports = [
    ./secrets.nix
  ];

  custom.nix.accessTokens = [
    "github.com=${config.sops.placeholder.github-pat-ccycle}"
  ];
}
