{ inputs, pkgs, ... }:
{
  home.packages = [
    inputs.serena.packages.${pkgs.system}.serena
  ];
}
