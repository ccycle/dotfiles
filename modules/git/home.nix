{ pkgs, config, ... }: {
  # All git settings live in the repo as writable gitconfig files
  # (modules/git/gitconfig and per-feature siblings included from it),
  # so edits apply without a rebuild.
  programs.git.includes = [
    {
      path = "${config.custom.dotfiles.dir}/modules/git/gitconfig";
    }
  ];

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
