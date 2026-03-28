{ ... }:

{
  imports = [
    ../opencloud/darwin.nix
    ../caddy/darwin.nix
    ../dnsmasq/darwin.nix
    ../immich/darwin.nix
    ../monitoring/darwin.nix
    ../gitlab/darwin.nix
    ../lm-studio/darwin.nix
  ];

  networking.hostName = "mac-mini-m4-pro";

  services.tailscale.splitDns.enable = true;

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

  # Enable macOS Remote Login (SSH on port 22)
  system.activationScripts.postActivation.text = ''
    if ! systemsetup -getremotelogin | grep -q "On"; then
      systemsetup -setremotelogin on
    fi
  '';
}
