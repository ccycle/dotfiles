{ config, lib, ... }:

let
  vol = config.custom.storage.volumeRoot;
  hasVol = vol != "";
in
{
  imports = [
    ./options.nix
  ];

  services.opencloud.dataDir = lib.mkIf hasVol (lib.mkDefault "${vol}/opencloud/data");
  services.opencloud.configDir = lib.mkIf hasVol (lib.mkDefault "${vol}/opencloud/config");
  services.opencloud.mountPoint = lib.mkIf hasVol (lib.mkDefault vol);
}
