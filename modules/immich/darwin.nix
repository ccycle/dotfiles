{ config, lib, ... }:

let
  vol = config.custom.storage.volumeRoot;
  hasVol = vol != "";
in
{
  imports = [
    ./options.nix
  ];

  services.immich.uploadDir = lib.mkIf hasVol (lib.mkDefault "${vol}/immich/upload");
  services.immich.dbDir = lib.mkIf hasVol (lib.mkDefault "${vol}/immich/db");
  services.immich.mountPoint = lib.mkIf hasVol (lib.mkDefault vol);
}
