{ config, ... }:

{
  imports = [
    ./secrets.nix
  ];

  custom.nix.accessTokens = [
    "gitlab.com=${config.sops.placeholder.gitlab-pat-ccycle}"
  ];
}
