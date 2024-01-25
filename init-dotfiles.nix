{ writeShellScriptBin }: writeShellScriptBin "init-dotfiles"
  ''
    cp --verbose -nr ${./templates}/*.nix $@
  ''
