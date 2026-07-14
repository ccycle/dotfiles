{ lib, ... }:

{
  imports = [
    ./options.nix
  ];

  services.opencloud.dataDir = lib.mkDefault "/Volumes/KIOXIA/opencloud/data";
  services.opencloud.configDir = lib.mkDefault "/Volumes/KIOXIA/opencloud/config";
  services.opencloud.mountPoint = lib.mkDefault "/Volumes/KIOXIA";
}
