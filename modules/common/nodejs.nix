{ pkgs, ... }: {
  home.packages = with pkgs; [
    node2nix
    nodePackages.prettier
    nodePackages.ts-node
    nodePackages.webpack
    nodejs
    typescript
    yarn
    yarn2nix
  ];
  imports = [
    ./nodejs/eslint.nix
    ./nodejs/yarn-install.nix
  ];
}
