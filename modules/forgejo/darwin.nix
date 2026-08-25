{ config, lib, ... }:

with lib;

let
  warnIfVolumeMissing = import ../../utils/warnIfVolumeMissing.nix;
  vol = warnIfVolumeMissing lib "forgejo" (config.custom.storage.volumes.forgejo or "");
  cfg = config.services.forgejo;
in
{
  imports = [
    ./options.nix
  ];

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = vol != "";
        message = "custom.storage.volumes.forgejo must be set. Run: scripts/setup-local-storage.sh forgejo=/Volumes/<YOUR_DRIVE>";
      }
    ];

    services.forgejo.dataDir = mkDefault "${vol}/forgejo/data";
    services.forgejo.mountPoint = mkIf (hasPrefix "/Volumes/" vol) (mkDefault vol);
  };
}
