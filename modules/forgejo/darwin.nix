{ config, lib, ... }:

let
  vol = config.custom.storage.volumeRoot;
  hasVol = vol != "";
in
{
  imports = [
    ./options.nix
  ];

  services.forgejo.dataDir = lib.mkIf hasVol (lib.mkDefault "${vol}/forgejo/data");
  services.forgejo.mountPoint = lib.mkIf hasVol (lib.mkDefault vol);
}
