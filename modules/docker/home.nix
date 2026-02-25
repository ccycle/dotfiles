{ pkgs, ... }: {
  home.packages = [ pkgs.docker ];
  imports = [ ./colima/home.nix ];
}
