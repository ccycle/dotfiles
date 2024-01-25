{ system, stack2cabal, ... }:
{
  home.packages = [ stack2cabal.defaultPackage.${system} ];
}
