{ buildGoModule, src }:
buildGoModule {
  pname = "gwq";
  version = "master";
  inherit src;
  # If a flake.lock bump breaks this with a hash mismatch or "inconsistent
  # vendoring", refresh with: nix-update --flake --version skip gwq --build
  vendorHash = "sha256-4K01Xf1EXl/NVX1loQ76l1bW8QglBAQdvlZSo7J4NPI=";
  doCheck = false;
}
