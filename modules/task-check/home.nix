{ pkgs, ... }:
let
  task-check = pkgs.callPackage ./drv.nix { };
in
{
  home.packages = [ task-check ];
}
