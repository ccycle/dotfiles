{ pkgs, ... }: {
  imports = [
    ../../bootstrap/modules/home-manager/git.nix
    ./git/ghq.nix
    ./git/github.nix
    ./git/gitlab.nix
  ];
}
