{ config, lib, ... }:

let
  vol = config.custom.storage.volumeRoot;
  hasVol = vol != "";
in
{
  imports = [
    ./options.nix
  ];

  services.gitlab.dataDir = lib.mkIf hasVol (lib.mkDefault "${vol}/gitlab/data");
  services.gitlab.configDir = lib.mkIf hasVol (lib.mkDefault "${vol}/gitlab/config");
  services.gitlab.logsDir = lib.mkIf hasVol (lib.mkDefault "${vol}/gitlab/logs");
  services.gitlab.mountPoint = lib.mkIf hasVol (lib.mkDefault vol);
}
