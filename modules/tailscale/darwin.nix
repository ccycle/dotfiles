{ config, lib, pkgs, tailscalePackage, ... }:

{
  services.tailscale.enable = true;
  # services.tailscale.overrideLocalDns = true;
  services.tailscale.package = tailscalePackage;
}
