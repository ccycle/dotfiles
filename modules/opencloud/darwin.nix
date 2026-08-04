{ config, lib, ... }:

with lib;

let
  vol = config.custom.storage.volumes.opencloud or "";
  cfg = config.services.opencloud;
in
{
  imports = [
    ./options.nix
  ];

  config = mkIf cfg.enable {
    assertions = [{
      assertion = vol != "";
      message = "custom.storage.volumes.opencloud must be set. Run: scripts/setup-local-storage.sh opencloud=/Volumes/<YOUR_DRIVE>";
    }];

    services.opencloud.dataDir = mkDefault "${vol}/opencloud/data";
    services.opencloud.configDir = mkDefault "${vol}/opencloud/config";
    services.opencloud.userFilesDir = mkDefault "${vol}/opencloud/user-files";
    services.opencloud.mountPoint = mkIf (hasPrefix "/Volumes/" vol) (mkDefault vol);
  };
}
