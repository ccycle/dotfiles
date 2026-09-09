{ buildGoModule, src }:
buildGoModule {
  pname = "gcx";
  version = "master";
  inherit src;
  # If a flake.lock bump breaks this with a hash mismatch or "inconsistent
  # vendoring", refresh with: nix-update --flake --version skip gcx --build
  vendorHash = "sha256-oBCpBz5GSuUVQyA3KmEcv1CjHaZvTGmmZSfKLufTmiE=";
  doCheck = false;
}
