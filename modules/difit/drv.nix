{ pkgs
, nodejs
, ...
}:
let
  npmDeps = pkgs.importNpmLock.buildNodeModules {
    npmRoot = ./.;
    inherit nodejs;
  };
in
pkgs.buildNpmPackage {
  pname = "difit";
  version = "latest";

  src = ./.;

  inherit npmDeps;

  # Use the hook compatible with importNpmLock
  npmConfigHook = pkgs.importNpmLock.hooks.linkNodeModulesHook;

  # Prevent buildNpmPackage from running npm install/ci as importNpmLock handles it
  dontNpmInstall = true;
  dontNpmBuild = true;

  installPhase = ''
    mkdir -p $out/bin

    # Link only the difit binary — avoid exposing lib/node_modules to prevent
    # collisions with other npm-based packages (e.g. shared deps like "marked").
    if [ -f "${npmDeps}/node_modules/.bin/difit" ]; then
      ln -s ${npmDeps}/node_modules/.bin/difit $out/bin/difit
    fi
  '';
}
