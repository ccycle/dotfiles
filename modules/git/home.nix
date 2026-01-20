{ pkgs, ... }: {
  imports = [
    ./ghq.nix
    ./gwq.nix
    ./github.nix
    ./gitlab.nix
  ];
}
