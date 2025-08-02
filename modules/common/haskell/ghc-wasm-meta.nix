{ ghc-wasm-meta, system, ... }:
{
  home.packages = with ghc-wasm-meta.packages.${system}; [
    wasm32-wasi-ghc-9_10
  ];
}
