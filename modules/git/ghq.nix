{ pkgs, config, ... }: {
  programs.git.settings = {
    ghq.root = "${config.home.homeDirectory}/repositories";
  };
  home.packages = with pkgs; [
    ghq
  ];
  imports = [
    ./ghq/ghq-migrator.nix
    ./ghq/peco.nix
  ];
}
