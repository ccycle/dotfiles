{ pkgs, ... }: {
  home.packages = with pkgs; [
    nodejs
    prefetch-npm-deps
    pnpm
    yarn
    typescript
    devcontainer

    # Node packages
    nodePackages.npm-check-updates
    nodePackages.ts-node
    nodePackages.webpack
    # nodePackages.webpack-cli

    # Custom packages managed via pnpm
    (callPackage ./node-tools/drv.nix { })
  ];
  imports = [
    ./eslint.nix
  ];
}
