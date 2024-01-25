{ stdenv, ghcup }:
stdenv.mkDerivation {
  name = "ghcup";
  src = ghcup;
  installPhase = "sh ./scripts/bootstrap/bootstrap-haskell";
}
