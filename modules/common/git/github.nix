{ pkgs, ... }:
# let
#   gmake = pkgs.callPackage ../gmake { };
#   github-linguist = pkgs.callPackage ./github/linguist { inherit gmake; };
# in
{
  home.packages = [
    pkgs.gh
    # github-linguist
  ];
}
