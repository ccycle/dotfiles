{ pkgs, inputs, config, ... }: {
  home.packages = [
    inputs.nix-claude-code.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  home.file."${config.home.homeDirectory}/.claude/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${config.custom.dotfiles.dir}/modules/claude/settings.json";

  home.file."${config.home.homeDirectory}/.claude/hooks".source =
    config.lib.file.mkOutOfStoreSymlink "${config.custom.dotfiles.dir}/modules/claude/hooks";

  home.file."${config.home.homeDirectory}/.claude/agents".source =
    config.lib.file.mkOutOfStoreSymlink "${config.custom.dotfiles.dir}/.agents/agents";

  programs.git.ignores = [
    ".claude/worktrees/"
  ];
}
