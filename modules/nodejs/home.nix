{ pkgs, ... }:
{
  home.packages = with pkgs; [
    nodejs
    prefetch-npm-deps
    pnpm
    yarn
    typescript
    devcontainer
    npm-check-updates

    # Custom packages managed via pnpm
    (callPackage ./node-tools/drv.nix { })
  ];
  imports = [
    ./bun/home.nix
    ./eslint/home.nix
  ];
}
