{ pkgs, ... }:
{
  home.packages = with pkgs; [ eslint ];
  programs.git.ignores = [ ".eslintcache/" ];
}
