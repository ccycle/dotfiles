{ inputs, system, ... }:
{
  home.packages = with inputs.ghc-wasm-meta.packages.${system}; [
    wasm32-wasi-ghc-9_10
  ];
}
