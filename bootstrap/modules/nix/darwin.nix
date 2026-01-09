{ config, lib, pkgs, ... }:

{
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
        extra-access-tokens = ${builtins.concatStringsSep " " tokens}
      '';
    path = "/etc/nix/access-tokens.conf";
  };

  nix = {
    extraOptions = ''
      !include ${config.sops.templates."nix-access-tokens.conf".path}
    '';
    channel.enable = false;
    package = lib.mkForce pkgs.nix;
    settings = {
      extra-substituters = [
        "https://cache.nixos.org"
        "https://cache.iog.io"
        "https://cache.zw3rk.com"
      ];
      trusted-public-keys = [
        "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
        "loony-tools:pr9m4BkM/5/eSTZlkQyRt57Jz7OMBxNSUiMC4FkcNfk="
      ];
      max-jobs = "auto";
      cores = 0;
    };
  };
}
