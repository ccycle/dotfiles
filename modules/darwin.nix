{ ... }:
{
  imports = [
    ./brew-nix/darwin.nix
    ./cachix/darwin.nix
    ./nix/darwin.nix
    ./ssh/darwin.nix
    ./tailscale/darwin.nix
    ./zsh/darwin.nix
  ];
}
