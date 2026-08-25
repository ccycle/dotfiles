{ pkgs, ... }:
{
  home.packages = with pkgs; [
    ghq
  ];
  imports = [
    ./ghq-migrator/home.nix
    ./peco/home.nix
  ];
}
