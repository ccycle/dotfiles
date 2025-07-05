{ pkgs, ... }:
# let
#   gmake = pkgs.callPackage ../gmake { };
#   github-linguist = pkgs.callPackage ./github/linguist { inherit gmake; };
# in
{
  # GitHub CLIの基本設定
  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "https";
      prompt = "enabled";
    };
  };
}
