{ lib, ... }:

{
  imports = [
    ./options.nix
  ];

  services.monitoring.enable = true;
  services.monitoring.dataDir = lib.mkDefault "/Volumes/KIOXIA/monitoring";
}
