{ config, lib, ... }:

{
  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 4d --keep 3";
    flake = lib.mkIf (config.custom.dotfiles.dir != "") config.custom.dotfiles.dir;
  };
}
