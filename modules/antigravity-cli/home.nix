{
  config,
  lib,
  ...
}:
{
  # The installer script (./install.sh) is exposed below as ~/.local/bin/agy-install
  # to install the agy binary imperatively (official docs:
  # https://antigravity.google/docs/cli/install/). Because the Nix package only
  # exists in nixpkgs-unstable and agy self-updates in the background on every
  # run, home-manager manages only the installer entrypoint and settings.json.
  home.file.".local/bin/agy-install".source = ./install.sh;

  # settings.json is rewritten by agy at runtime (e.g. during first-run setup or
  # configuration updates), so an out-of-store symlink lets those changes land
  # in the tracked file instead of a Nix-owned copy — same pattern as
  # ~/.claude/settings.json (see modules/claude/home.nix). The CLI persists
  # only non-default values, so the empty baseline stays valid across updates.
  home.file."${config.home.homeDirectory}/.gemini/antigravity-cli/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${config.custom.dotfiles.dir}/modules/antigravity-cli/settings.json";

  home.activation.antigravityCliCheck = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -x "$HOME/.local/bin/agy" ]; then
      echo "Warning: agy not found at ~/.local/bin/agy -- install it with: agy-install" >&2
    fi
  '';
}
