{ config, lib, pkgs, tailscalePackage, ... }:

{
  imports = [
    ./options.nix
  ];

  services.tailscale.enable = true;
  # services.tailscale.overrideLocalDns = true;
  services.tailscale.package = tailscalePackage;
}
