{ config, lib, pkgs, pkgs-unstable, ... }:

{
  services.tailscale.enable = true;
  # services.tailscale.overrideLocalDns = true;
  # services.tailscale.package = pkgs-unstable.tailscale;
}
