{ ghq-migrator, stdenv, coreutils }:
stdenv.mkDerivation {
  name = "ghq-migrator";
  src = ghq-migrator;
  buildInputs = [ coreutils ];
  passAsFile = [ "entrypoint" ];
  entrypoint = "GHQ_MIGRATOR_ACTUALLY_RUN=1 ghq-migrator.bash $@";
  installPhase = ''
    mkdir -p $out/bin
    install -t $out/bin ghq-migrator.bash
    install --mode 555 -D $entrypointPath $out/bin/ghq-migrator-run
  '';
}
