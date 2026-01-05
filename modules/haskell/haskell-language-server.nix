{ pkgs, pkgs-unstable, self, ... }:
let
  setPriorities = pkgs.callPackage "${self}/utils/setPrioritiesAsc.nix" { };
in
{
  home.packages = setPriorities
    [
      # pkgs-unstable.haskell.packages.ghc966.haskell-language-server
      # pkgs-unstable.haskell.packages.ghc948.haskell-language-server
      # pkgs-unstable.haskell.packages.ghc928.haskell-language-server
      # pkgs.haskell.packages.ghc8107.haskell-language-server
    ];
}
