{ ... }:
{
  imports = [
    ./cabal/home.nix
    ./compiler/home.nix
    ./dev-tools/home.nix
    # ./ghc-wasm-meta/home.nix
    ./haskell-language-server/home.nix
  ];
}
