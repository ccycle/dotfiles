{
  stdenv,
  fetchurl,
  findutils,
}:
{ url, sha256 }:
let
  matches = builtins.match "^https\:\/\/github\.com\/([^\/]+)\/([^\.]+)\/releases/download/([^\/]+)\/([^\/]+)" url;
  owner = builtins.elemAt matches 0;
  repoName = builtins.elemAt matches 1;
  tag = builtins.elemAt matches 2;
in
stdenv.mkDerivation {
  pname = repoName;
  version = tag;
  src = fetchurl {
    inherit url sha256;
  };
  nativeInputs = [ findutils ];
  phases = [ "installPhase" ];
  installPhase = ''
    mkdir -p $out/bin
    tar -xf $src
    find . -type f -executable ! -name "*.*" ! -name "LICENSE" | xargs -I {} cp {} $out/bin
  '';
}
