{ pkgs, inputs, ... }:
let
  gwq = pkgs.callPackage ./gwq/drv.nix {
    src = inputs.gwq;
  };
in
{
  home.packages = [ gwq ];
}
