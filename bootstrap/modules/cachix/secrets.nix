{ pkgs, ... }:
{
  sops.secrets.cachix-auth-token-ccycle = {
    sopsFile = ./secrets.yaml;
    format = "yaml";
  };

  # sops.templates."cachix.dhall" = {
  #   content = ''
  #     { authToken = "${config.sops.placeholder.cachix_auth_token}"
  #     , hostname = "https://cachix.org"
  #     , binaryCaches = [] : List { name : Text, secretKey : Text }
  #     }
  #   '';
  #   path = "${config.xdg.configHome}/cachix/cachix.dhall";
  # };
}
