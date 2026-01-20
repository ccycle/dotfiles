{ buildGoModule, src }:
buildGoModule {
  pname = "gwq";
  version = "master";
  inherit src;
  # Update this hash if the build fails with a hash mismatch
  vendorHash = "sha256-c1vq9yETUYfY2BoXSEmRZj/Ceetu0NkIoVCM3wYy5iY=";
  doCheck = false;
}
