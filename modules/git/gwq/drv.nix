{ buildGoModule, src }:
buildGoModule {
  pname = "gwq";
  version = "master";
  inherit src;
  # Update this hash if the build fails with a hash mismatch
  vendorHash = "sha256-4K01Xf1EXl/NVX1loQ76l1bW8QglBAQdvlZSo7J4NPI=";
  doCheck = false;
}
