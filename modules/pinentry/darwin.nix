{ lib, ... }:
{
  options.custom.pinentry.headless = lib.mkEnableOption ''
    treating this host as headless for pinentry purposes. No local GUI
    session is ever available (nothing but SSH/herdr reaches it), so
    modules/pinentry/home.nix skips SSH_TTY/SSH_CONNECTION detection
    (which herdr's long-lived server process never refreshes per
    connection anyway) and always selects pinentry-curses
  '';
}
