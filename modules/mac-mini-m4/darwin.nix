{ ... }:

{
  imports = [
    ../opencloud/darwin.nix
    ../nextcloud/darwin.nix
    ../caddy/darwin.nix
    ../dnsmasq/darwin.nix
    ../immich/darwin.nix
    ../monitoring/darwin.nix
  ];

  networking.hostName = "mac-mini-m4";
}
