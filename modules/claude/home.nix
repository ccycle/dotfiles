{
  pkgs,
  inputs,
  config,
  ...
}:
{
  home.packages = [
    # Upstream prepends an unwrapped gh to PATH, which would bypass the rbw read-only wrapper in ../git/github/gh/home.nix: https://github.com/ryoppippi/nix-claude-code/blob/6eb6dfee5454cf5270d6d94bb453cb6e956b3ef7/flake.nix#L35
    (inputs.nix-claude-code.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
      additionalPaths = [ "${pkgs.poppler-utils}/bin" ];
    })
  ];

  home.file."${config.home.homeDirectory}/.claude/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${config.custom.dotfiles.dir}/modules/claude/settings.json";

  home.file."${config.home.homeDirectory}/.claude/hooks".source =
    config.lib.file.mkOutOfStoreSymlink "${config.custom.dotfiles.dir}/modules/claude/hooks";

  programs.git.ignores = [
    ".claude/worktrees/"
  ];
}
