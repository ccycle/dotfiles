{ callPackage, self }:
callPackage "${self}/utils/mkDerivationFromGitHubRelease.nix" { }
{
  url = "https://github.com/FiloSottile/age/releases/download/v1.1.1/age-v1.1.1-darwin-amd64.tar.gz";
  sha256 = "0z122va8f30hj75631q006dxl8409jih48lms6qb3232j0kzmgc1";
}
