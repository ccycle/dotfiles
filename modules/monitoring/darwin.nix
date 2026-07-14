{ lib, ... }:

{
  imports = [
    ./options.nix
  ];

  services.monitoring.dataDir = lib.mkDefault "/Volumes/KIOXIA/monitoring";
}
