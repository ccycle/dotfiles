{ pkgs, inputs, ... }: {
  brew-nix.enable = true;
  imports = [ inputs.brew-nix.darwinModules.default ];
}
