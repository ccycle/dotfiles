{ ... }:
{
  imports = [
    ./haskell/ghcup.nix
    ./haskell/cabal.nix
    # ./haskell/compiler.nix
    ./haskell/dev-tools.nix
    # ./haskell/haskell-language-server.nix
    ./haskell/stack.nix
  ];
}
