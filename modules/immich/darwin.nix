{ config, lib, ... }:

with lib;

let
  warnIfVolumeMissing = import ../../utils/warnIfVolumeMissing.nix;
  vol = warnIfVolumeMissing lib "immich" (config.custom.storage.volumes.immich or "");
  cfg = config.services.immich;
in
{
  imports = [
    ./options.nix
  ];

  config = mkIf cfg.enable {
    assertions = [{
      assertion = vol != "";
      message = "custom.storage.volumes.immich must be set. Run: scripts/setup-local-storage.sh immich=/Volumes/<YOUR_DRIVE>";
    }];

    services.immich.uploadDir = mkDefault "${vol}/immich/upload";
    services.immich.dbDir = mkDefault "${vol}/immich/db";
    services.immich.mountPoint = mkIf (hasPrefix "/Volumes/" vol) (mkDefault vol);
  };
}
