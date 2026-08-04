{ config, lib, ... }:

with lib;

let
  warnIfVolumeMissing = import ../../utils/warnIfVolumeMissing.nix;
  vol = warnIfVolumeMissing lib "gitlab" (config.custom.storage.volumes.gitlab or "");
  cfg = config.services.gitlab;
in
{
  imports = [
    ./options.nix
  ];

  config = mkIf cfg.enable {
    assertions = [{
      assertion = vol != "";
      message = "custom.storage.volumes.gitlab must be set. Run: scripts/setup-local-storage.sh gitlab=/Volumes/<YOUR_DRIVE>";
    }];

    services.gitlab.dataDir = mkDefault "${vol}/gitlab/data";
    services.gitlab.configDir = mkDefault "${vol}/gitlab/config";
    services.gitlab.logsDir = mkDefault "${vol}/gitlab/logs";
    services.gitlab.mountPoint = mkIf (hasPrefix "/Volumes/" vol) (mkDefault vol);
  };
}
