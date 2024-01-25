{ pkgs, ... }: {
  home.packages = with pkgs; [ nixpkgs-fmt ];
  programs.zsh.shellAliases = {
    nix-format-all = ''
      find . -name "*.nix" | xargs nixpkgs-fmt
    '';
  };
}
