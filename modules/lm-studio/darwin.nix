{ ... }:
{
  home-manager.sharedModules = [
    ({ pkgs, ... }: {
      home.packages = [ pkgs.brewCasks.lm-studio ];
    })
  ];
}
