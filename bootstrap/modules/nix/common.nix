{ config, lib, pkgs, ... }:

{
  nix = {
    channel.enable = false;
    package = lib.mkForce pkgs.nix;
    settings = {
      extra-substituters = [
        "https://cache.nixos.org"
        "https://cache.iog.io"
        "https://cache.zw3rk.com"
      ];
      trusted-public-keys = [
        "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
        "loony-tools:pr9m4BkM/5/eSTZlkQyRt57Jz7OMBxNSUiMC4FkcNfk="
      ];
      max-jobs = "auto";
      cores = 0;
    };
  };
}
