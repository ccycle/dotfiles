{ config, lib, pkgs, username, ... }:

{
  options.custom.nix.accessTokens = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "List of access tokens for nix.conf in format 'host=token'";
  };

  config = {
    sops.templates."nix-access-tokens.conf" = {
      content =
        let
          tokens = config.custom.nix.accessTokens;
        in
        ''
          extra-access-tokens = ${builtins.concatStringsSep " " tokens}
        '';
      path = "/etc/nix/nix-access-tokens.conf";
      owner = username;
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
  };
}
