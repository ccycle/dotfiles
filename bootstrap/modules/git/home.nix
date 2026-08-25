{ pkgs, ... }:
{
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
  imports = [
    ./user/home.nix
  ];
  home.packages = [
    pkgs.git-lfs
    pkgs.git-credential-oauth
  ];
}
