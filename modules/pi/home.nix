{ piPackage, ... }:

{
  # See ./design.md for why pi is packaged via the pi.nix flake rather than
  # buildNpmPackage/importNpmLock in modules/nodejs/node-tools. Config files
  # are symlinked directly (see modules/ai-rules/home.nix) rather than going
  # through pi.nix's programs.pi.coding-agent home-manager module.
  home.packages = [ piPackage ];
}
