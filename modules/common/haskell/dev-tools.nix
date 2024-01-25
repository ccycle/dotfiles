{ pkgs, ... }:
{
  home.packages = (with pkgs;
    [
      ghcid
      haskellPackages.tasty-discover
      hpack
    ]);
}
