{ pkgs, ... }:
{
  home.packages = [
    (pkgs.callPackage ./drv.nix { })
  ];
}
