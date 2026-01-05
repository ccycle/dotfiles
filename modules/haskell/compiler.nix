{ pkgs, pkgs-unstable, self, ... }:
let setPrioritiesAsc = pkgs.callPackage "${self}/utils/setPrioritiesAsc.nix" { }; in
{
  # home.packages =
  #   setPrioritiesAsc (
  #     [
  #       pkgs-unstable.haskell.compiler.ghc947
  #       pkgs-unstable.haskell.compiler.ghc928
  #       pkgs.haskell.compiler.ghc8107
  #     ]);
  # imports = [ ./ghc-wasm-meta.nix ];
}
