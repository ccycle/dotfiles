{ pkgs, ... }:
let
  # Mirrors modules/docker/orbstack/darwin.nix's userBin: kiac/container
  # only exist in this user's home-manager profile, and kiac itself is a
  # per-user tool (like OrbStack), so this runs as a user agent.
  userBin = "/etc/profiles/per-user/mfuruki/bin";
in
{
  home-manager.sharedModules = [ ./home.nix ];

  environment.etc."newsyslog.d/kiac-resume.conf".text = ''
    # logfilename                              [owner:group]     mode  count  size  when  flags
    /Users/mfuruki/Library/Logs/kiac-resume.log  mfuruki:staff  644   7      10240 *     GZ
  '';

  # One-shot: bring the "homelab" cluster back after a host reboot. Fine
  # to fail harmlessly (logged, not retried) before any cluster has been
  # created yet — see modules/kiac/darwin.nix's Phase 0 setup in the
  # migration plan.
  launchd.user.agents.kiac-resume = {
    serviceConfig = {
      RunAtLoad = true;
      StandardOutPath = "/Users/mfuruki/Library/Logs/kiac-resume.log";
      StandardErrorPath = "/Users/mfuruki/Library/Logs/kiac-resume.log";
    };
    script = ''
      export PATH="${userBin}:$PATH"
      kiac resume cluster --name homelab || echo "kiac resume cluster failed (no cluster yet?)"
    '';
  };
}
