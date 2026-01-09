{ pkgs, ... }: {
  imports = [
    ./ghq.nix
    ./github.nix
    ./gitlab.nix
  ];
}
