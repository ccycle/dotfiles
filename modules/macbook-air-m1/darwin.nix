{
  lib,
  ...
}:

{
  networking.hostName = "macbook-air-m1";

  custom.dotfiles.dir = lib.mkDefault "/Users/ccycle/repositories/github.com/ccycle/dotfiles";
  services.comin.enable = true;
}
