{ pkgs, stack2cabal, ... }:
let
  stack2cabalDrv = pkgs.haskellPackages.callCabal2nix "stack2cabal" stack2cabal { }
  ;
in
{
  home.packages = [ stack2cabalDrv ];
}
