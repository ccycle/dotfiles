{ config, ... }:

{
  imports = [
    ./options.nix
    ../../bootstrap/modules/cachix/darwin.nix
  ];

  services.cachix-watch-store = {
    enable = true;
    cacheName = "ccycle";
    cachixTokenFile = config.sops.secrets.cachix-auth-token-ccycle.path;
  };
}
