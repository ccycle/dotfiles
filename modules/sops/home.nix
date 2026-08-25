{ config, pkgs, ... }:
{
  home.packages = with pkgs; [
    age
    sops
  ];
  sops.age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
  sops.age.sshKeyPaths = [ ];
  sops.gnupg.sshKeyPaths = [ ];
}
