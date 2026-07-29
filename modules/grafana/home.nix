{ pkgs, inputs, ... }:
let
  gcx = pkgs.callPackage ./drv.nix { src = inputs.gcx; };
in
{
  home.packages = [ gcx ];
}
