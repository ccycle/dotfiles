{
  pkgs,
  config,
  lib,
  ...
}:
{
  options.custom.git.configSource = lib.mkOption {
    type = lib.types.str;
    default = "${config.custom.dotfiles.dir}/modules/git/gitconfig";
    description = "Path to the base gitconfig file, symlinked to ~/.config/git/config.";
  };

  config = {
    programs.git = {
      enable = true;
      ignores = [
        "*~"
        "*.swp"
        ".DS_Store"
        "worktree-*"
        "*.log"
        "*.local"
        "result-*"
        "result"
        ".my-local-workspace/"
      ];
    };

    xdg.configFile."git/config" = lib.mkForce {
      source = config.lib.file.mkOutOfStoreSymlink config.custom.git.configSource;
    };
    xdg.configFile."git/github/gitconfig".source =
      config.lib.file.mkOutOfStoreSymlink "${config.custom.dotfiles.dir}/modules/git/github/gitconfig";
    # Templated (not a static symlinked file, unlike gitconfig/github/gitconfig
    # above): the root path is per-machine (config.home.homeDirectory), so it
    # can't be a literal committed file - see modules/comin/design.md for why
    # that matters on the comin-managed hosts specifically.
    xdg.configFile."git/ghq/gitconfig".text = ''
      [ghq]
          root = ${config.home.homeDirectory}/repositories
    '';

    home.packages = [
      pkgs.git-lfs
      pkgs.git-credential-oauth
    ];
  };

  imports = [
    ./ghq/home.nix
    ./github/home.nix
    ./gitlab/home.nix
    ./gwq/home.nix
    ./user/home.nix
  ];
}
