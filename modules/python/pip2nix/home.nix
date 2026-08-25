{
  pkgs,
  inputs,
  system,
  ...
}:
{
  home.packages = [ inputs.pip2nix.defaultPackage.${system} ];
}
