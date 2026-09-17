{
  config,
  pkgs,
  username,
  ...
}:

{
  environment.etc."ssh/sshd_config.d/102-use-dns.conf".text = ''
    # Disable DNS lookup to speed up SSH connections
    # This helps when DNS resolution is slow or failing (common in VPN/Tailscale)
    UseDNS no
  '';

  # Alternative SSHD on port 2222
  launchd.daemons.sshd-alt = {
    serviceConfig = {
      Label = "com.local.sshd-alt";
      ProgramArguments = [
        "/usr/sbin/sshd"
        "-D"
        "-p"
        "2222"
      ];
      KeepAlive = true;
      RunAtLoad = true;
    };
  };

  # Reload keychain-stored SSH passphrases into Apple's launchd-managed
  # ssh-agent at GUI login, so non-interactive contexts (agents, GUI apps)
  # can sign git commits without a passphrase prompt. Interactive SSH
  # sessions are covered by the zsh fallback in home.nix. Absolute
  # /usr/bin path because system SSH is used on macOS (see home.nix) and
  # launchd jobs run with a minimal PATH.
  launchd.user.agents.ssh-apple-load-keychain = {
    serviceConfig = {
      RunAtLoad = true;
      StandardOutPath = "/var/tmp/ssh-apple-load-keychain.log";
      StandardErrorPath = "/var/tmp/ssh-apple-load-keychain.log";
    };
    script = ''
      /usr/bin/ssh-add --apple-load-keychain
    '';
  };
}
