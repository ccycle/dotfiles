{ pkgs, inputs, ... }: {
  home.packages = [
    inputs.claude-code-nix.packages.${pkgs.system}.claude-code
  ];

  home.file.".claude/skills".source = ../../skills;
}
