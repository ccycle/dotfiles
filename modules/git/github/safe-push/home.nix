{ config, pkgs, ... }:
let
  git-safe-push = pkgs.callPackage ./drv.nix {
    tokenFile = config.sops.secrets.github-agent-push-token.path;
  };
in
{
  # Fine-grained PAT (contents: read/write, selected repos only) used
  # exclusively by git-safe-push. Human pushes keep using GCM device flow.
  sops.secrets.github-agent-push-token = {
    sopsFile = ./secrets.yaml;
  };

  home.packages = [ git-safe-push ];
}
