{ config, lib, ... }:

with lib;

let
  vol = config.custom.storage.volumeRoot;
  cfg = config.services.monitoring;
in
{
  imports = [
    ./options.nix
  ];

  config = mkIf cfg.enable {
    assertions = [{
      assertion = vol != "";
      message = "custom.storage.volumeRoot must be set for monitoring. Run: scripts/setup-local-storage.sh /Volumes/<YOUR_DRIVE>";
    }];

    services.monitoring.dataDir = mkDefault "${vol}/monitoring";
    services.monitoring.mountPoint = mkDefault vol;

    services.monitoring.gitlabLogsDir = mkIf config.services.gitlab.enable (
      mkDefault config.services.gitlab.logsDir
    );
  };
}
