{ ... }:
{
  imports = [
    # ./haskell/ghcup.nix
    ./haskell/compiler.nix
    ./haskell/haskell-language-server.nix
    ./haskell/cabal.nix
    ./haskell/dev-tools.nix
    ./haskell/stack.nix
  ];
}
