{ pkgs, config, lib, ... }: {
  options.custom.git.configSource = lib.mkOption {
    type = lib.types.str;
    default = "${config.custom.dotfiles.dir}/modules/git/gitconfig";
    description = "Path to the base gitconfig file, symlinked to ~/.config/git/config.";
  };

  config = {
    xdg.configFile."git/config" = lib.mkForce {
      source =
        config.lib.file.mkOutOfStoreSymlink config.custom.git.configSource;
    };
    xdg.configFile."git/github/gitconfig".source =
      config.lib.file.mkOutOfStoreSymlink "${config.custom.dotfiles.dir}/modules/git/github/gitconfig";
    xdg.configFile."git/ghq/gitconfig".source =
      config.lib.file.mkOutOfStoreSymlink "${config.custom.dotfiles.dir}/modules/git/ghq/gitconfig";

    home.packages = [
      pkgs.git-credential-oauth
    ];
  };

  imports = [
    ./ghq/home.nix
    ./github/home.nix
    ./gitlab/home.nix
    ./gwq/home.nix
  ];
}
