{
  outputs =
    { ... }:
    {
      # Default for a real interactive bootstrap run (documented usage:
      # `nix run ./bootstrap -- switch --flake ./bootstrap`, a single
      # command on a fresh machine) - $USER/$SUDO_USER are reliably set
      # there. bootstrap/scripts/ensure-user.sh generates an id -un based
      # override at .local/user for CI/dry-run validation instead, where
      # $USER is not set (see bootstrap/flake.nix). Self-contained on
      # purpose - see bootstrap/flake.nix's own header comment on why this
      # flake avoids sharing abstractions with the root one.
      username =
        if builtins.getEnv "SUDO_USER" != "" then builtins.getEnv "SUDO_USER" else builtins.getEnv "USER";
      homeDirectory =
        if builtins.getEnv "SUDO_USER" != "" then
          if builtins.pathExists "/Users" then
            "/Users/${builtins.getEnv "SUDO_USER"}"
          else
            "/home/${builtins.getEnv "SUDO_USER"}"
        else
          builtins.getEnv "HOME";
    };
}
