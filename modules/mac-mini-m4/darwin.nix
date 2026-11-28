{
  lib,
  ...
}:

{
  networking.hostName = "mac-mini-m4";

  # No local GUI session ever available (see modules/pinentry/darwin.nix).
  custom.pinentry.headless = true;

  custom.dotfiles.dir = lib.mkDefault "/Users/ccycle/repositories/github.com/ccycle/dotfiles";
  custom.storage.volumes = lib.mkDefault {
    opencloud = "/Volumes/KIOXIA";
    monitoring = "/Volumes/KIOXIA";
    immich = "/Volumes/KIOXIA";
  };
  services.comin.enable = true;

  services.tailscale.splitDns.enable = true;
  services.opencloud.enable = true;
  services.caddy.enable = true;
  custom.dnsmasq.enable = true;
  services.immich.enable = true;
  custom.kiac.enable = true;
  # The LAN router, same resolver the host itself uses (scutil --dns).
  custom.kiac.dnsServers = [ "192.168.10.1" ];
  services.pocket-id.enable = true;
  services.monitoring.enable = true;
  services.monitoring.notify.ntfyHost = "mac-mini-m4-pro";
}
