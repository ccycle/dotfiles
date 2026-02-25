{ ... }:
{
  imports = [
    ./brew-nix/darwin.nix
    ./cachix/darwin.nix
    ./docker/darwin.nix
    ./nix/darwin.nix
    ./ssh/darwin.nix
    ./stylix/darwin.nix
    ./tailscale/darwin.nix
    ./zsh/darwin.nix
  ];
}
