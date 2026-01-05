{ pkgs, ... }: {
  imports = [
    ../../bootstrap/modules/git/home.nix
    ./ghq.nix
    ./github.nix
    ./gitlab.nix
  ];
}
