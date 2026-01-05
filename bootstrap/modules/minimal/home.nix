{ config, pkgs, username, homeDirectory, ... }:

{
  imports = [
    ../git/home.nix
  ];

  home.username = username;
  home.homeDirectory = homeDirectory;

  home.stateVersion = "25.05";

  programs.home-manager.enable = true;
  xdg.enable = true;
}
