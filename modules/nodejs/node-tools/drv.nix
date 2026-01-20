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
  pname = "node-tools";
  version = "1.0.0";

  src = ./.;

  inherit npmDeps;

  # Use the hook compatible with importNpmLock
  npmConfigHook = pkgs.importNpmLock.hooks.linkNodeModulesHook;

  # Prevent buildNpmPackage from running npm install/ci as importNpmLock handles it
  dontNpmInstall = true;
  dontNpmBuild = true;

  installPhase = ''
    mkdir -p $out/bin
    
    ln -s ${npmDeps}/node_modules $out/node_modules

    # Link binaries
    if [ -d "${npmDeps}/node_modules/.bin" ]; then
      ln -s ${npmDeps}/node_modules/.bin/* $out/bin/
    fi
  '';
}
