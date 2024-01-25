{ pkgs, pip2nix, system, ... }:
{
  home.packages = [ pip2nix.defaultPackage.${system} ];
}
