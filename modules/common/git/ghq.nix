{ pkgs, ... }: {
  programs.git.extraConfig = {
    ghq.root = "~/repositories";
  };
  home.packages = with pkgs; [
    ghq
  ];
  imports = [
    ./ghq/ghq-migrator.nix
    ./ghq/peco.nix
  ];
}
