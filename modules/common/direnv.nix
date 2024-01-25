{ ... }: {
  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;
  programs.git.ignores = [
    ".direnv"
    ".env.local"
  ];
}
