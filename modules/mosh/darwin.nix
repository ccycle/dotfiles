{ config, ... }:

{
  # mosh-server needs to accept incoming UDP connections. macOS's application
  # firewall would otherwise show a GUI prompt on first launch, which never
  # gets answered on this headless host — pre-approve the binary instead.
  #
  # The firewall records the resolved store path, not the /etc/profiles
  # symlink, so resolve it before checking --listapps; this also means a
  # mosh package upgrade (new store path) needs this to run again.
  system.activationScripts.postActivation.text = ''
    moshServer="/etc/profiles/per-user/${config.system.primaryUser}/bin/mosh-server"
    if [ -x "$moshServer" ]; then
      resolvedMoshServer="$(readlink -f "$moshServer")"
      if ! /usr/libexec/ApplicationFirewall/socketfilterfw --listapps 2>/dev/null | grep -qF "$resolvedMoshServer"; then
        echo "allowing mosh-server through the application firewall..." >&2
        /usr/libexec/ApplicationFirewall/socketfilterfw --add "$moshServer" >/dev/null 2>&1 || true
        /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp "$moshServer" >/dev/null 2>&1 || true
      fi
    fi
  '';
}
