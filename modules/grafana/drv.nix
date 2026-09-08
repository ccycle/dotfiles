{ buildGoModule, src }:
buildGoModule {
  pname = "gcx";
  version = "master";
  inherit src;
  vendorHash = "sha256-oBCpBz5GSuUVQyA3KmEcv1CjHaZvTGmmZSfKLufTmiE=";
  doCheck = false;
}
