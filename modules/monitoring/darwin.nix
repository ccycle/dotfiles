{ ... }:

{
  imports = [
    ./options.nix
  ];

  services.monitoring.enable = true;
  services.monitoring.dataDir = "/Volumes/KIOXIA/monitoring";
}
