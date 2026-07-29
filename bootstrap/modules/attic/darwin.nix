{ config, lib, ... }:

{
  # Attic substituter configuration for all machines.
  #
  # After init.sh has been run and atticd is serving on mac-mini-m4-pro,
  # fill in the public key below:
  #
  #   ssh mac-mini-m4-pro -- attic cache info dotfiles
  #
  nix.settings = {
    extra-substituters = [ "https://cache.mac-mini-m4-pro.internal" ];
    trusted-public-keys = [ "dotfiles:<PUBLIC_KEY>" ];
  };
}
