{ ... }:

{
  # Attic substituter configuration for all machines.
  #
  # After atticd is running and a cache has been created on mac-mini-m4-pro,
  # uncomment and fill in the values below:
  #
  #   ssh mac-mini-m4-pro -- attic cache info dotfiles
  #
  # nix.settings = {
  #   extra-substituters = [ "https://cache.mac-mini-m4-pro.internal" ];
  #   trusted-public-keys = [ "dotfiles:<PUBLIC_KEY>" ];
  # };
}
