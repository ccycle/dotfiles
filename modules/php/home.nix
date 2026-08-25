{ pkgs, ... }:
{
  home.packages = (
    with pkgs;
    [
      php82Packages.composer
    ]
  );
}
