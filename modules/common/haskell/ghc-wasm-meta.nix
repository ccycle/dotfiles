{ pkgs, ghc-wasm-meta, system, ... }:
let filterDrv = pkgs.callPackage ../../../utils/filterDrv.nix {}; in
{
  home.packages = with ghc-wasm-meta.packages.${system}; [
    wasm32-wasi-ghc-9_10
  ] ;
}
