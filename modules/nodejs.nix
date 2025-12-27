{ pkgs, ... }: {
  home.packages = with pkgs; [
    node2nix
    nodejs
    yarn2nix
  ];
  imports = [
    ./nodejs/eslint.nix
    ./nodejs/yarn-install.nix
    ./nodejs/npm-install.nix
  ];
}
