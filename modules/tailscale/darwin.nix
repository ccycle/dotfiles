{
  config,
  lib,
  pkgs,
  tailscalePackage,
  ...
}:

{
  imports = [
    ./options.nix
  ];

  services.tailscale.enable = true;
  # services.tailscale.overrideLocalDns = true;
  services.tailscale.package = tailscalePackage;

  # Route .internal domain DNS queries to Tailscale MagicDNS.
  # macOS Tailscale only auto-creates /etc/resolver/ts.net but not for
  # custom Split DNS domains. Without this, .internal queries fall through
  # to the ISP DNS and fail with NXDOMAIN.
  environment.etc."resolver/internal".text = ''
    nameserver 100.100.100.100
  '';
}
