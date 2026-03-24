{ ... }:

{
  imports = [
    ../opencloud/darwin.nix
    ../caddy/darwin.nix
    ../dnsmasq/darwin.nix
    ../immich/darwin.nix
    ../monitoring/darwin.nix
    ../gitlab/darwin.nix
  ];

  networking.hostName = "mac-mini-m4-pro";

  services.tailscale.splitDns.enable = true;
  services.tailscale.splitDns.tailnet = ""; # TODO: set tailnet name

  # Override paths for WD_BLACK external drive
  services.opencloud.dataDir = "/Volumes/WD_BLACK/opencloud/data";
  services.opencloud.configDir = "/Volumes/WD_BLACK/opencloud/config";
  services.opencloud.mountPoint = "/Volumes/WD_BLACK";

  services.immich.uploadDir = "/Volumes/WD_BLACK/immich/upload";
  services.immich.dbDir = "/Volumes/WD_BLACK/immich/db";
  services.immich.mountPoint = "/Volumes/WD_BLACK";

  services.monitoring.dataDir = "/Volumes/WD_BLACK/monitoring";

  services.gitlab.dataDir = "/Volumes/WD_BLACK/gitlab/data";
  services.gitlab.configDir = "/Volumes/WD_BLACK/gitlab/config";
  services.gitlab.logsDir = "/Volumes/WD_BLACK/gitlab/logs";
  services.gitlab.mountPoint = "/Volumes/WD_BLACK";
}
