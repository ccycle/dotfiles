{ pkgs, inputs, ... }:
{
  home.packages = [ (pkgs.callPackage ./drv.nix { ghq-migrator = inputs.ghq-migrator; }) ];
  programs.zsh.shellAliases = {
    ghq-migrator-run-all = ''
      ls | xargs -I{} ghq-migrator-run {}
    '';
  };
}
