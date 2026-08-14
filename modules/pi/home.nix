{ piPackage, pkgs, ... }:

{
  # See ./design.md for why pi is packaged via the pi.nix flake rather than
  # buildNpmPackage/importNpmLock in modules/nodejs/node-tools. Config files
  # are symlinked directly (see modules/ai-rules/home.nix) rather than going
  # through pi.nix's programs.pi.coding-agent home-manager module.
  #
  # Only bin/pi is added to the profile, not piPackage itself: piPackage's
  # lib/node_modules vendors its own zod, at the same path modules/openclaw
  # uses for its own (different) zod, so merging both into the shared
  # profile via buildEnv fails with a file collision. bin/pi is a
  # makeWrapper script with NODE_PATH baked in as an absolute store path, so
  # it doesn't need lib/ present in the profile to run correctly.
  home.packages = [
    (pkgs.runCommand "pi-coding-agent-bin" { } ''
      mkdir -p $out/bin
      ln -s ${piPackage}/bin/pi $out/bin/pi
    '')
  ];
}
