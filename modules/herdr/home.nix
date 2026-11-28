{
  herdrPackage,
  config,
  lib,
  pkgs,
  ...
}:

{
  home.packages = [
    herdrPackage
    # Optional external renderers for herdr-file-viewer (markdown/diff/syntax highlighting)
    pkgs.glow
    pkgs.delta
    pkgs.bat
  ];

  programs.zsh.initContent = ''
    source <(${herdrPackage}/bin/herdr completion zsh)
  '';

  home.file."${config.home.homeDirectory}/.config/herdr/config.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${config.custom.dotfiles.dir}/modules/herdr/config.toml";

  home.file."${config.home.homeDirectory}/.config/herdr/scripts/group-workspaces.sh".source =
    config.lib.file.mkOutOfStoreSymlink "${config.custom.dotfiles.dir}/modules/herdr/group-workspaces.sh";

  home.file."${config.home.homeDirectory}/.config/herdr/plugins/config/persiyanov.reviewr/config.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${config.custom.dotfiles.dir}/modules/herdr/reviewr-config.toml";

  home.file.".local/bin/herdr-install-plugins".source = ./install-plugins.sh;

  # herdr ships a built-in agent-state integration for pi (writes
  # ~/.pi/agent/extensions/herdr-agent-state.ts), analogous to the Claude
  # integration installed separately by herdr itself. Install/update it here
  # so pi panes get agent-panel labels, state tracking, and `herdr agent
  # start --kind pi` detection like claude already has.
  home.activation.herdr-pi-integration-install = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    if "${herdrPackage}/bin/herdr" integration status 2>/dev/null | grep -q "^pi: current"; then
      echo "[herdr-pi-integration-install] already up to date, skipping"
    else
      echo "[herdr-pi-integration-install] installing pi integration"
      if "${herdrPackage}/bin/herdr" integration install pi; then
        echo "[herdr-pi-integration-install] install succeeded"
      else
        echo "[herdr-pi-integration-install] Warning: install failed. Run 'herdr integration install pi' manually."
      fi
    fi
  '';
}
