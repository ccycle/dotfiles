{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    sops
  ];

  sops = {
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
  };
}
