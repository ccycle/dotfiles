{ lib, ... }:

{
  options.custom.dnsmasq = {
    enable = lib.mkEnableOption "dnsmasq for *.<host>.internal on the Tailscale IP";
  };
}
