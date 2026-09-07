{ buildGoModule, src }:
buildGoModule {
  pname = "gcx";
  version = "master";
  inherit src;
  vendorHash = "sha256-Ka5rFZAiqdKCKjQ3X2Ba+PawiEx4swdk9NBBED9DmYM=";
  doCheck = false;
}
