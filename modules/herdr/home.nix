{
  herdrPackage,
  config,
  lib,
  ...
}:

{
  home.packages = [ herdrPackage ];

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
    if ! "${herdrPackage}/bin/herdr" plugin list 2>/dev/null | grep -q "persiyanov.reviewr"; then
      "${herdrPackage}/bin/herdr" plugin install persiyanov/herdr-reviewr -y \
        || echo "Warning: failed to install herdr-reviewr. Run 'herdr plugin install persiyanov/herdr-reviewr' manually."
    fi
  '';
}
