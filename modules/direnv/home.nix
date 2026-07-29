{ config, ... }: {
  home.file."${config.home.homeDirectory}/.config/direnv/direnvrc".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.custom.dotfiles.dir}/modules/direnv/direnvrc";

  programs = {
    direnv = {
      enable = true;
      nix-direnv.enable = true;
      enableZshIntegration = true;
    };
    git.ignores = [
      ".direnv"
      ".env.local"
    ];
  };
}
