{ pkgs-unstable, inputs, ... }:
let
  gwq = pkgs-unstable.callPackage ./gwq/drv.nix {
    src = inputs.gwq;
  };
in
{
  home.packages = [ gwq ];
}
