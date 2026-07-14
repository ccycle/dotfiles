{ pkgs, config, ... }: {
  programs.git.settings = {
    ghq.root = "${config.home.homeDirectory}/repositories";
  };
  home.packages = with pkgs; [
    ghq
  ];
  imports = [
    ./ghq-migrator/home.nix
    ./peco/home.nix
  ];
}
