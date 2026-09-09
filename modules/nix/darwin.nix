{
  config,
  lib,
  pkgs,
  inputs,
  username,
  ...
}:

{
  imports = [
  ];

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

    nix.nixPath = lib.mkForce [ "nixpkgs=${inputs.nixpkgs}" ];
    nix.channel.enable = false;
    nix.package = lib.mkForce pkgs.nix;
    nix.extraOptions = ''
      !include ${config.sops.templates."nix-access-tokens.conf".path}
    '';
    nix.settings.nix-path = lib.mkForce [ "nixpkgs=${inputs.nixpkgs}" ];
    nix.settings.auto-optimise-store = true;
    nix.settings.extra-substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://cache.iog.io"
      "https://cache.zw3rk.com"
    ];
    nix.settings.trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
      "loony-tools:pr9m4BkM/5/eSTZlkQyRt57Jz7OMBxNSUiMC4FkcNfk="
    ];
    nix.settings.max-jobs = "auto";
    nix.settings.cores = 0;

    nix.settings.trusted-users = [ username ];
  };
}
