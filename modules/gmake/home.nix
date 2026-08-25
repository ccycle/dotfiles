{ pkgs, ... }:
let
  gmake = pkgs.callPackage ./gmake/drv.nix { };
in
{
  home.packages = [ gmake ];
}
