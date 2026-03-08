{ ... }:

{
  imports = [
    ./options.nix
  ];

  services.opencloud.enable = true;
  services.opencloud.dataDir = "/Volumes/KIOXIA/opencloud/data";
  services.opencloud.configDir = "/Volumes/KIOXIA/opencloud/config";
  services.opencloud.mountPoint = "/Volumes/KIOXIA";
}
