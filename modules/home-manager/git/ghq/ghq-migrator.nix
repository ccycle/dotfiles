{ pkgs, ghq-migrator, ... }: {
  home.packages =
    [ (pkgs.callPackage ./ghq-migrator/default.nix { inherit ghq-migrator; }) ];
  programs.zsh.shellAliases = {
    ghq-migrator-run-all = ''
      ls | xargs -I{} ghq-migrator-run {}
    '';
  };
}
