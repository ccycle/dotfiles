{ pkgs, ... }:
let gmake = pkgs.callPackage ./default.nix { }; in
{
  home.packages = [ gmake ];
}
