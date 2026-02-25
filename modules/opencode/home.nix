{ pkgs, inputs, ... }: {
  home.packages = [
    inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.opencode
    inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.desktop
  ];
}
