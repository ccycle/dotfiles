{ ... }:
{
  # bws (Bitwarden Secrets Manager CLI) ships under the Bitwarden SDK License,
  # which nixpkgs marks unfree. Being unfree it is not on cache.nixos.org, so it
  # builds from Rust source locally.
  custom.nix.unfreePackages = [ "bws" ];
}
