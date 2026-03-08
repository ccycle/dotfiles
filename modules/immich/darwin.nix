{ ... }:

{
  imports = [
    ./options.nix
  ];

  services.immich.enable = true;
  services.immich.uploadDir = "/Volumes/KIOXIA/immich/upload";
  services.immich.dbDir = "/Volumes/KIOXIA/immich/db";
  services.immich.mountPoint = "/Volumes/KIOXIA";
}
