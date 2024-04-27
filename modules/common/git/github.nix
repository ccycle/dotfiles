{ pkgs, ... }:
let github-linguist = pkgs.callPackage ./github/linguist { }; in
{
  home.packages = [ pkgs.gh github-linguist ];
}
