{ config, lib, pkgs, ... }:

{
  imports = [
    ./git/github/secrets.nix
    ./git/gitlab/secrets.nix
    ./cachix/secrets.nix
  ];

  sops.templates."nix-access-tokens.conf" = {
    content =
      let
        tokens = [
          "github.com=${config.sops.placeholder.github-pat-ccycle}"
          "github.com=${config.sops.placeholder.github-pat-primal-search}"
          "gitlab.com=${config.sops.placeholder.gitlab-pat-ccycle}"
          "ccycle.cachix.org=${config.sops.placeholder.cachix-auth-token-ccycle}"
        ];
      in
      ''
        access-tokens = ${builtins.concatStringsSep " " tokens}
      '';
    path = "/etc/nix/access-tokens.conf";
  };

  nix = {
    channel.enable = false;
    package = lib.mkForce pkgs.nix;
    settings = {
      substituters = [
        "https://cache.nixos.org"
        "https://cache.iog.io"
        "https://cache.zw3rk.com"
        "https://nix-community.cachix.org"
        "https://ccycle.cachix.org"
      ];
      trusted-public-keys = [
        "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
        "loony-tools:pr9m4BkM/5/eSTZlkQyRt57Jz7OMBxNSUiMC4FkcNfk="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "ccycle.cachix.org-1:rEb6IyD7NBEujI5+0MrkgdDNWuz+UMe8sDyttbaEnRE="
      ];
      max-jobs = "auto";
      cores = 0;
    };
    extraOptions = ''
      !include ${config.sops.templates."nix-access-tokens.conf".path}
    '';
  };
}
