{ pkgs, ... }: {
  home.packages = with pkgs; [
    node2nix
    nodejs
    nodePackages.ts-node
    nodePackages.webpack
    typescript
    yarn
    yarn2nix
  ];
  imports = [
    ./nodejs/eslint.nix
    ./nodejs/yarn-install.nix
  ];
}
