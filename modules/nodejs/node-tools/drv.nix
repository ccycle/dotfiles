{
  pkgs,
  nodejs,
  ...
}:
let
  rawLock = builtins.fromJSON (builtins.readFile ./package-lock.json);

  # importNpmLock cannot gracefully skip optional dependencies that fail
  # to build (unlike npm). Strip them from the lockfile before building.
  excludeOptionalPackages =
    names: lock:
    let
      modulePaths = map (n: "node_modules/${n}") names;
      stripOptDeps =
        _: pkg:
        if pkg ? optionalDependencies then
          pkg // { optionalDependencies = builtins.removeAttrs pkg.optionalDependencies names; }
        else
          pkg;
    in
    lock
    // {
      packages = builtins.mapAttrs stripOptDeps (builtins.removeAttrs lock.packages modulePaths);
    };

  # importNpmLock rewrites resolved URLs to file: store paths, but
  # hasShrinkwrap packages carry their own npm-shrinkwrap.json with
  # registry URLs that npm follows in offline mode → fetch failure.
  # Stripping hasShrinkwrap makes npm use the rewritten lockfile.
  # Their nested deps without integrity must also be dropped.
  fixShrinkwrap =
    lock:
    let
      noIntegrity = builtins.filter (
        p: p != "" && !(lock.packages.${p} ? integrity) && !(lock.packages.${p} ? link)
      ) (builtins.attrNames lock.packages);
    in
    lock // {
      packages = builtins.mapAttrs (
        _: pkg: builtins.removeAttrs pkg [ "hasShrinkwrap" ]
      ) (builtins.removeAttrs lock.packages noIntegrity);
    };

  npmDeps = pkgs.importNpmLock.buildNodeModules {
    npmRoot = ./.;
    packageLock = fixShrinkwrap (excludeOptionalPackages [ "keytar" ] rawLock);
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

    # Link binaries, skipping pi (provided by modules/pi via piPackage)
    for bin in ${npmDeps}/node_modules/.bin/*; do
      [ "$(basename "$bin")" = "pi" ] && continue
      ln -s "$bin" "$out/bin/"
    done
  '';
}
