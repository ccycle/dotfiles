{ pkgs
, nodejs
, ...
}:
let
  rawLock = builtins.fromJSON (builtins.readFile ./package-lock.json);

  # importNpmLock cannot fetch git+ssh:// URLs. Strip problematic packages
  # from the lockfile before building.
  excludePackages = names: lock:
    let
      modulePaths = map (n: "node_modules/${n}") names;
      stripDeps = _: pkg:
        builtins.foldl'
          (acc: depAttr:
            if acc ? ${depAttr} then
              acc // { ${depAttr} = builtins.removeAttrs acc.${depAttr} names; }
            else
              acc
          )
          pkg [ "dependencies" "optionalDependencies" ];
    in
    lock // {
      packages = builtins.mapAttrs stripDeps (builtins.removeAttrs lock.packages modulePaths);
    };

  npmDeps = pkgs.importNpmLock.buildNodeModules {
    npmRoot = ./.;
    packageLock = excludePackages [
      "libsignal"
      "libsignal/node_modules/@types/node"
      "libsignal/node_modules/long"
      "libsignal/node_modules/protobufjs"
    ]
      rawLock;
    inherit nodejs;
  };
in
pkgs.buildNpmPackage {
  pname = "openclaw";
  version = "latest";

  src = ./.;

  inherit npmDeps;

  # Use the hook compatible with importNpmLock
  npmConfigHook = pkgs.importNpmLock.hooks.linkNodeModulesHook;

  # Prevent buildNpmPackage from running npm install/ci as importNpmLock handles it
  dontNpmInstall = true;
  dontNpmBuild = true;

  installPhase = ''
    mkdir -p $out/bin $out/lib

    # Keep node_modules under lib/ to avoid collisions with other npm packages
    ln -s ${npmDeps}/node_modules $out/lib/node_modules

    # Link only the openclaw binary
    if [ -f "${npmDeps}/node_modules/.bin/openclaw" ]; then
      ln -s ${npmDeps}/node_modules/.bin/openclaw $out/bin/openclaw
    fi
  '';
}
