{ ... }:
{
  imports = [
    # ./ghcup.nix
    ./compiler.nix
    ./haskell-language-server.nix
    ./cabal.nix
    ./dev-tools.nix
  ];
}
