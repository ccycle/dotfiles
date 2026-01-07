{ config, lib, pkgs, ... }:

{
  imports = [
    ../git/github/secrets.nix
    ../git/gitlab/secrets.nix
    ../cachix/secrets.nix
    ../cachix/darwin.nix
    ./common.nix
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
        extra-access-tokens = ${builtins.concatStringsSep " " tokens}
      '';
    path = "/etc/nix/access-tokens.conf";
  };

  nix = {
    extraOptions = ''
      !include ${config.sops.templates."nix-access-tokens.conf".path}
    '';
  };
}
