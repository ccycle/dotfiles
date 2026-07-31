{ config, lib, ... }:

with lib;

let
  vol = config.custom.storage.volumeRoot;
  cfg = config.services.opencloud;
in
{
  imports = [
    ./options.nix
  ];

  config = mkIf cfg.enable {
    assertions = [{
      assertion = vol != "";
      message = "custom.storage.volumeRoot must be set for opencloud. Run: scripts/setup-local-storage.sh /Volumes/<YOUR_DRIVE>";
    }];

    services.opencloud.dataDir = mkDefault "${vol}/opencloud/data";
    services.opencloud.configDir = mkDefault "${vol}/opencloud/config";
    services.opencloud.userFilesDir = mkDefault "${vol}/opencloud/user-files";
    services.opencloud.mountPoint = mkDefault vol;
  };
}
