{ config, lib, ... }:

with lib;

let
  warnIfVolumeMissing = import ../../utils/warnIfVolumeMissing.nix;
  vol = warnIfVolumeMissing lib "navidrome" (config.custom.storage.volumes.navidrome or "");
  cfg = config.services.navidrome;
in
{
  imports = [
    ./options.nix
  ];

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = vol != "";
        message = "custom.storage.volumes.navidrome must be set. Run: scripts/setup-local-storage.sh navidrome=/Volumes/<YOUR_DRIVE>";
      }
    ];

    services.navidrome.dataDir = mkDefault "${vol}/navidrome/data";
    services.navidrome.musicDir = mkDefault "${vol}/navidrome/music";
    services.navidrome.mountPoint = mkIf (hasPrefix "/Volumes/" vol) (mkDefault vol);
  };
}
