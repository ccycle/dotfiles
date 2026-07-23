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

  home.file."${config.home.homeDirectory}/.config/herdr/config.toml".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.programs.git.settings.ghq.root}/github.com/ccycle/dotfiles/modules/herdr/config.toml";

  home.file."${config.home.homeDirectory}/.config/herdr/plugins/config/persiyanov.reviewr/config.toml".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.programs.git.settings.ghq.root}/github.com/ccycle/dotfiles/modules/herdr/reviewr-config.toml";

  # herdr-reviewr ships prebuilt binaries through herdr's plugin system, not as a flake,
  # so the binary cannot be managed by Nix. Install it once here; updates are manual
  # (uninstall then install, per upstream's instructions).
  home.activation.herdr-reviewr-install = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if "${herdrPackage}/bin/herdr" plugin list 2>/dev/null | grep -q "persiyanov.reviewr"; then
      echo "[herdr-reviewr-install] already installed, skipping"
    else
      echo "[herdr-reviewr-install] not found, installing persiyanov/herdr-reviewr"
      if "${herdrPackage}/bin/herdr" plugin install persiyanov/herdr-reviewr -y; then
        echo "[herdr-reviewr-install] install succeeded"
      else
        echo "[herdr-reviewr-install] Warning: install failed. Run 'herdr plugin install persiyanov/herdr-reviewr' manually."
      fi
    fi
  '';

  # herdr-file-viewer also ships through herdr's plugin system rather than as a flake.
  home.activation.herdr-file-viewer-install = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if "${herdrPackage}/bin/herdr" plugin list 2>/dev/null | grep -q "herdr-file-viewer"; then
      echo "[herdr-file-viewer-install] already installed, skipping"
    else
      echo "[herdr-file-viewer-install] not found, installing smarzban/herdr-file-viewer"
      if "${herdrPackage}/bin/herdr" plugin install smarzban/herdr-file-viewer -y; then
        echo "[herdr-file-viewer-install] install succeeded"
      else
        echo "[herdr-file-viewer-install] Warning: install failed. Run 'herdr plugin install smarzban/herdr-file-viewer' manually."
      fi
    fi
  '';
}
