{ config, lib, ... }:

with lib;

let
  vol = config.custom.storage.volumeRoot;
  cfg = config.services.immich;
in
{
  imports = [
    ./options.nix
  ];

  config = mkIf cfg.enable {
    assertions = [{
      assertion = vol != "";
      message = "custom.storage.volumeRoot must be set for immich. Run: scripts/setup-local-storage.sh /Volumes/<YOUR_DRIVE>";
    }];

    services.immich.uploadDir = mkDefault "${vol}/immich/upload";
    services.immich.dbDir = mkDefault "${vol}/immich/db";
    services.immich.mountPoint = mkDefault vol;
  };
}
