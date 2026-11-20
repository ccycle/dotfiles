{ config, lib, ... }:
let
  cfg = config.custom.kiac;
  # Mirrors modules/docker/orbstack/darwin.nix's userBin: kiac/container
  # only exist in this user's home-manager profile, and kiac itself is a
  # per-user tool (like OrbStack), so this runs as a user agent.
  userBin = "/etc/profiles/per-user/mfuruki/bin";
  dnsFlags = lib.concatMapStringsSep " " (ip: "--dns ${lib.escapeShellArg ip}") cfg.dnsServers;
in
{
  imports = [ ./options.nix ];

  config = lib.mkIf cfg.enable {
    home-manager.sharedModules = [ ./home.nix ];

    environment.etc."newsyslog.d/kiac-resume.conf".text = ''
      # logfilename                              [owner:group]     mode  count  size  when  flags
      /Users/mfuruki/Library/Logs/kiac-resume.log  mfuruki:staff  644   7      10240 *     GZ
    '';

    # One-shot at login: bring the "homelab" cluster back after a host
    # reboot, or create it on first run so the cluster itself is declared
    # here rather than by a hand-run `kiac create`.
    launchd.user.agents.kiac-resume = {
      serviceConfig = {
        RunAtLoad = true;
        StandardOutPath = "/Users/mfuruki/Library/Logs/kiac-resume.log";
        StandardErrorPath = "/Users/mfuruki/Library/Logs/kiac-resume.log";
      };
      script = ''
        # apple/container's signed installer puts `container` in /usr/local/bin
        # (see apple-container/scripts/install.sh), which launchd's PATH lacks.
        export PATH="${userBin}:/usr/local/bin:$PATH"
        set -euo pipefail
        # The runtime is down after a reboot; without the flag `system start`
        # prompts for a kernel install, which no one can answer under launchd.
        container system start --disable-kernel-install
        # Fail hard here: treating an unreachable runtime as "no cluster"
        # would create a second cluster over the real one.
        clusters=$(kiac get clusters)
        if printf '%s\n' "$clusters" | grep -q '^homelab '; then
          kiac resume cluster --name homelab
        else
          # --dns is only needed at create time: it is stored in each node
          # container's config and survives VM restarts.
          kiac create cluster --name homelab --distro k3s ${dnsFlags}
        fi
      '';
    };
  };
}
