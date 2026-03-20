{ lib, ... }:

{
  imports = [
    ./options.nix
  ];

  services.immich.enable = true;
  services.immich.uploadDir = lib.mkDefault "/Volumes/KIOXIA/immich/upload";
  services.immich.dbDir = lib.mkDefault "/Volumes/KIOXIA/immich/db";
  services.immich.mountPoint = lib.mkDefault "/Volumes/KIOXIA";
}
