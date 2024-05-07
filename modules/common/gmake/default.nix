{ gnumake, coreutils, stdenv }:
stdenv.mkDerivation {
  name = "gmake";
  version = gnumake.version;
  src = ./.;
  buildInputs = [ coreutils gnumake ];
  installPhase = ''
    mkdir -p $out/bin
    ln -s ${gnumake}/bin/make $out/bin/gmake
  '';
}
