{ config, ... }:
{
  home.file."${config.home.homeDirectory}/.config/direnv/direnvrc".source =
    config.lib.file.mkOutOfStoreSymlink "${config.custom.dotfiles.dir}/modules/direnv/direnvrc";

  programs = {
    direnv = {
      enable = true;
      nix-direnv.enable = true;
      enableZshIntegration = true;
      # Auto-trust every .envrc under herdr's worktree root (herdr creates worktrees at
      # ~/.herdr/worktrees/<repo>/<branch>), so new worktrees need no `direnv allow`.
      # Trade-off: this skips direnv's review step for any repo opened as a herdr worktree,
      # including third-party clones, so a malicious .envrc there runs on cd.
      # Worktrees made with `herdr worktree create --path` elsewhere are not covered.
      config.whitelist.prefix = [ "${config.home.homeDirectory}/.herdr/worktrees/" ];
    };
    git.ignores = [
      ".direnv"
      ".env.local"
    ];
  };
}
