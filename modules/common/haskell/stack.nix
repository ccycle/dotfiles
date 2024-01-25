{ pkgs, ... }:
{
  home.packages = with pkgs; [ stack ];
  programs.git.ignores = [
    ".stack-work"
  ];
  imports = [
    ./stack2cabal.nix
  ];
}
