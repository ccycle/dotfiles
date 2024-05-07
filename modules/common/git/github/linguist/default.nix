{ bundlerEnv, stdenv, ruby, gmake }:
let
  gems = bundlerEnv {
    pname = "github-linguist";
    exes = [ "github-linguist" ];
    inherit ruby;
    gemdir = ./.;
  };
in
stdenv.mkDerivation {
  name = "github-linguist";
  buildInputs = [ gems ruby gmake ];
}
