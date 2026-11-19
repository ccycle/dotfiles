{ lib, ... }:
{
  # The nixpkgs t3code package lags upstream far behind and cannot self-update
  # from the read-only store, so home-manager manages only the installer
  # entrypoint; t3 itself lives under ~/.t3 and updates with `t3 update`.
  home.file.".local/bin/t3-install".source = ./install.sh;

  home.activation.t3codeCheck = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -x "$HOME/.local/bin/t3" ]; then
      echo "Warning: t3 not found at ~/.local/bin/t3 -- install it with: t3-install" >&2
    fi
  '';
}
