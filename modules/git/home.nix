{ pkgs, config, lib, ... }: {
  # All git settings live in the repo as writable gitconfig files
  # (modules/git/gitconfig and per-feature siblings included from it).
  # ~/.config/git/config is a symlink into the repo, so edits apply without a
  # rebuild and `git config --global` writes through to the dotfiles files.
  # Relative includes in the base resolve against the symlink's directory
  # (~/.config/git/), so feature files are symlinked there too.
  xdg.configFile."git/config" = lib.mkForce {
    source =
      config.lib.file.mkOutOfStoreSymlink "${config.custom.dotfiles.dir}/modules/git/gitconfig";
  };
  xdg.configFile."git/github/gitconfig".source =
    config.lib.file.mkOutOfStoreSymlink "${config.custom.dotfiles.dir}/modules/git/github/gitconfig";
  xdg.configFile."git/ghq/gitconfig".source =
    config.lib.file.mkOutOfStoreSymlink "${config.custom.dotfiles.dir}/modules/git/ghq/gitconfig";

  home.packages = [
    pkgs.git-credential-oauth
  ];

  imports = [
    ./ghq/home.nix
    ./github/home.nix
    ./gitlab/home.nix
    ./gwq/home.nix
  ];
}
