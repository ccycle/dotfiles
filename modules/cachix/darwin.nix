{ config, ... }:

{
  imports = [
    ./options.nix
  ];

  services.cachix-watch-store = {
    enable = true;
    cacheName = "ccycle";
    cachixTokenFile = config.sops.secrets.cachix-auth-token-ccycle.path;
  };
}
