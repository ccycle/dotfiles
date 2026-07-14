{ pkgs-unstable, inputs, ... }:
let
  gwq = pkgs-unstable.callPackage ./drv.nix {
    src = inputs.gwq;
  };
in
{
  home.packages = [ gwq ];
}
