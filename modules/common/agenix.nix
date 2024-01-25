{ pkgs, agenix, system, ... }: {
  imports = [ agenix.homeManagerModules.age ];
  home.packages = [ agenix.packages.${system}.agenix ];
}
