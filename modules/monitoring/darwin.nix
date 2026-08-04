{ config, lib, ... }:

with lib;

let
  vol = config.custom.storage.volumes.monitoring or "";
  cfg = config.services.monitoring;
in
{
  imports = [
    ./options.nix
  ];

  config = mkIf cfg.enable {
    assertions = [{
      assertion = vol != "";
      message = "custom.storage.volumes.monitoring must be set. Run: scripts/setup-local-storage.sh monitoring=/Volumes/<YOUR_DRIVE>";
    }];

    services.monitoring.dataDir = mkDefault "${vol}/monitoring";
    services.monitoring.mountPoint = mkIf (hasPrefix "/Volumes/" vol) (mkDefault vol);

    services.monitoring.gitlabLogsDir = mkIf config.services.gitlab.enable (
      mkDefault config.services.gitlab.logsDir
    );
  };
}
