{ buildGoModule, src }:
buildGoModule {
  pname = "gcx";
  version = "master";
  inherit src;
  vendorHash = "";
  doCheck = false;
}
