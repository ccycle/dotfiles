{
  pkgs,
  nodejs,
  ...
}:
let
  lock = builtins.fromJSON (builtins.readFile ./package-lock.json);

  npmDeps = pkgs.importNpmLock.buildNodeModules {
    npmRoot = ./.;
    inherit nodejs;
    derivationArgs.postInstall = ''
      cp ${./require-builtin-shim.js} $out/node_modules/node-addon-require-builtin/lib/index.js
    '';
  };
in
# Not part of modules/nodejs/node-tools: dsh needs its own wrapper flag and
# a patched dependency, which that shared .bin linker cannot express.
pkgs.stdenvNoCC.mkDerivation {
  pname = "dsh";
  version = lock.packages."node_modules/@deepseek-ai/dsh".version;

  dontUnpack = true;
  nativeBuildInputs = [ pkgs.makeBinaryWrapper ];

  # --expose-internals is what the require-builtin shim loads internals through.
  installPhase = ''
    mkdir -p $out/bin
    makeBinaryWrapper ${nodejs}/bin/node $out/bin/dsh \
      --add-flags --expose-internals \
      --add-flags ${npmDeps}/node_modules/@deepseek-ai/dsh/lib/bin.js
  '';

  meta.mainProgram = "dsh";
}
