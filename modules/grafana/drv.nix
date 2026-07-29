{ buildGoModule, src }:
buildGoModule {
  pname = "gcx";
  version = "master";
  inherit src;
  vendorHash = "sha256-PevzovryzpNap8dzruYWdk07M5g9jlA8QPQcrXnO7xk=";
  doCheck = false;
}
