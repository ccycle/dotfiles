{ pkgs, inputs, ... }: {
  home.packages = [
    inputs.claude-code-nix.packages.${pkgs.system}.claude-code
  ];
}
