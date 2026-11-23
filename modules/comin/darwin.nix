{
  config,
  inputs,
  lib,
  pkgs,
  system,
  ...
}:

let
  cfg = config.services.comin;
  # Reuses the repo's existing SSH commit-signing trust root (modules/git/gitconfig,
  # modules/git/user/home.nix) rather than inventing a second one. comin
  # runs as a root launchd daemon, so it needs a system-readable copy of the
  # allowed_signers file - the home-manager-deployed ~/.config/git/allowed_signers
  # is scoped to the login user, not readable at system-activation time.
  signingKey = ../git/user/id_ed25519_signing.pub;
  cominWithoutActivateUser = inputs.comin.packages.${system}.comin.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./skip-activate-user.patch ];
  });
in
{
  imports = [
    inputs.comin.darwinModules.comin
  ];

  config = lib.mkIf cfg.enable {
    system.build.applications = lib.mkForce (
      pkgs.runCommand "system-applications-unmanaged-on-comin-hosts" { } "mkdir -p $out/Applications"
    );

    environment.etc."comin/allowed_signers".text =
      ''ccycle713@gmail.com namespaces="git" ${builtins.readFile signingKey}'';

    services.comin = {
      package = cominWithoutActivateUser;
      sshAllowedSignersPath = "/etc/comin/allowed_signers";

      # Loopback-bound, scraped by Prometheus via the same host-gateway
      # pattern as node-exporter/Caddy - see modules/monitoring/prometheus.yml.
      exporter.listen_address = "127.0.0.1";

      # Ordered: Forgejo first (LAN, low latency), GitHub as fallback so a
      # Forgejo outage - which this same repo also causes when it manages
      # Forgejo itself (see modules/forgejo/design.md) - doesn't strand
      # deploys. See modules/comin/design.md.
      # No auth: both repos are publicly readable, and comin sends Basic auth
      # whenever a token is set, so a wrong token turns a working anonymous
      # fetch into "authentication required".
      remotes = [
        {
          name = "forgejo";
          url = "https://forgejo.mac-mini-m4-pro.internal/ccycle/dotfiles.git";
        }
        {
          name = "github";
          url = "https://github.com/ccycle/dotfiles";
        }
      ];
    };
  };
}
