{ config, lib, ... }:

with lib;

let
  vol = config.custom.storage.volumeRoot;
  cfg = config.services.gitlab;
in
{
  imports = [
    ./options.nix
  ];

  config = mkIf cfg.enable {
    assertions = [{
      assertion = vol != "";
      message = "custom.storage.volumeRoot must be set for gitlab. Run: scripts/setup-local-storage.sh /Volumes/<YOUR_DRIVE>";
    }];

    services.gitlab.dataDir = mkDefault "${vol}/gitlab/data";
    services.gitlab.configDir = mkDefault "${vol}/gitlab/config";
    services.gitlab.logsDir = mkDefault "${vol}/gitlab/logs";
    services.gitlab.mountPoint = mkDefault vol;
  };
}
