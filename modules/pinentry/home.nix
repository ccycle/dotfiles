{
  pkgs,
  lib,
  # Only set when this home-manager config is built through nix-darwin's
  # integration (home-manager.users.<user> inside a darwinConfiguration —
  # see the home-manager wiring in darwin.nix), which is how all of
  # bootstrap/private/mac-mini-m4/mac-mini-m4-pro are actually deployed (darwin-rebuild).
  # The standalone `homeConfigurations.private` flake output (plain
  # `home-manager switch`, e.g. on Linux) never provides it.
  darwinConfig ? { },
  ...
}:
lib.mkIf pkgs.stdenv.isDarwin (
  let
    # On a headless host (no local GUI session ever reachable — see
    # modules/pinentry/darwin.nix), always use pinentry-curses: SSH_TTY
    # detection below is moot there anyway, since herdr's long-lived server
    # process never refreshes it per connection (see the tailscale-acl-apply
    # session's investigation).
    headless = darwinConfig.custom.pinentry.headless or false;

    # rbw forwards PINENTRY_USER_DATA from the calling client on every
    # unlock/login/2FA request (see rbw::protocol::ENVIRONMENT_VARIABLES),
    # unlike SSH_TTY/SSH_CONNECTION, which the long-lived rbw-agent process
    # never receives — it keeps whatever environment it happened to be
    # spawned in, which may be a stale local (or SSH) session. Shell startup
    # below exports PINENTRY_USER_DATA=ssh whenever $SSH_TTY/$SSH_CONNECTION
    # is set, so this selector reliably picks the terminal-only backend for
    # the current request regardless of which session started the agent.
    pinentrySelector =
      if headless then
        pkgs.writeShellScript "pinentry-selector" ''
          exec "${pkgs.pinentry-curses}/bin/pinentry-curses" "$@"
        ''
      else
        pkgs.writeShellScript "pinentry-selector" ''
          case "''${PINENTRY_USER_DATA:-}" in
            ssh) exec "${pkgs.pinentry-curses}/bin/pinentry-curses" "$@" ;;
            *) exec "${pkgs.pinentry_mac}/bin/pinentry-mac" "$@" ;;
          esac
        '';
  in
  {
    home.packages = [
      pkgs.pinentry-curses
    ]
    ++ lib.optional (!headless) pkgs.pinentry_mac;

    # rbw's pinentry setting lives in an imperative local config file
    # (~/Library/Application Support/rbw/config.json on Darwin), not
    # something home-manager can express declaratively, so an activation
    # script keeps it pointed at the current selector.
    home.activation.rbw-pinentry-config = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      if "${pkgs.rbw}/bin/rbw" config show 2>/dev/null | grep -qF "${pinentrySelector}"; then
        echo "[rbw-pinentry-config] already up to date, skipping"
      else
        echo "[rbw-pinentry-config] setting rbw pinentry to ${pinentrySelector}"
        "${pkgs.rbw}/bin/rbw" config set pinentry "${pinentrySelector}"
      fi
    '';

    programs.zsh.initContent = lib.mkIf (!headless) ''
      if [ -n "''${SSH_TTY:-}''${SSH_CONNECTION:-}" ]; then
        export PINENTRY_USER_DATA=ssh
      fi
    '';
  }
)
