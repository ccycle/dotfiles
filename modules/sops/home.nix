{ config, pkgs, ... }:
{
  home.packages = [ pkgs.sops ];
  sops.age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
  sops.age.sshKeyPaths = [ ];
  sops.gnupg.sshKeyPaths = [ ];
}
