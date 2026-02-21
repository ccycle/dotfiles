{ pkgs
, nodejs
, ...
}:
let
  rawLock = builtins.fromJSON (builtins.readFile ./package-lock.json);

  # importNpmLock cannot gracefully skip optional dependencies that fail
  # to build (unlike npm). Strip them from the lockfile before building.
  excludeOptionalPackages = names: lock:
    let
      modulePaths = map (n: "node_modules/${n}") names;
      stripOptDeps = _: pkg:
        if pkg ? optionalDependencies then
          pkg // { optionalDependencies = builtins.removeAttrs pkg.optionalDependencies names; }
        else
          pkg;
    in
    lock // {
      packages = builtins.mapAttrs stripOptDeps (builtins.removeAttrs lock.packages modulePaths);
    };

  npmDeps = pkgs.importNpmLock.buildNodeModules {
    npmRoot = ./.;
    packageLock = excludeOptionalPackages [ "keytar" ] rawLock;
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
