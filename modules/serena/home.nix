{ inputs, pkgs, ... }:
{
  home.packages = [
    inputs.serena.packages.${pkgs.stdenv.hostPlatform.system}.serena
  ];
}
