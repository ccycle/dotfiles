{ ... }:

{
  networking.hostName = "mac-mini-m4";

  services.tailscale.splitDns.enable = true;
  services.opencloud.enable = true;
  services.caddy.enable = true;
  custom.dnsmasq.enable = true;
  services.immich.enable = true;
  services.monitoring.enable = true;
}
