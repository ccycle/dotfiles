{
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  cfg = config.custom.kiac;
  # Mirrors modules/docker/orbstack/darwin.nix's userBin: kiac/container
  # only exist in this user's home-manager profile, and kiac itself is a
  # per-user tool (like OrbStack), so this runs as a user agent.
  userBin = "/etc/profiles/per-user/${username}/bin";
  dnsFlags = lib.concatMapStringsSep " " (ip: "--dns ${lib.escapeShellArg ip}") cfg.dnsServers;
  node = "kiac-homelab-control-plane";
  textfileDir = "/var/lib/node-exporter-textfile";
  logs = [
    "/var/log/kiac-resume.log"
    "/var/log/kiac-health.log"
  ];
in
{
  imports = [ ./options.nix ];

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.monitoring.enable;
        message = "custom.kiac requires services.monitoring.enable = true: its agents write node_exporter textfile metrics.";
      }
    ];

    home-manager.sharedModules = [ ./home.nix ];

    system.activationScripts.preActivation.text = ''
      for f in ${lib.concatStringsSep " " logs}; do
        touch "$f"
        chown ${username}:staff "$f"
      done
    '';

    environment.etc."newsyslog.d/kiac.conf".text = ''
      # logfilename  [owner:group]  mode  count  size  when  flags
      ${lib.concatMapStringsSep "\n" (f: "${f}  ${username}:staff  644  7  10240  *  GZ") logs}
    '';

    # One-shot at login: bring the "homelab" cluster back after a host
    # reboot, or create it on first run so the cluster itself is declared
    # here rather than by a hand-run `kiac create`.
    launchd.user.agents.kiac-resume = {
      serviceConfig = {
        RunAtLoad = true;
        StandardOutPath = "/var/log/kiac-resume.log";
        StandardErrorPath = "/var/log/kiac-resume.log";
      };
      script = ''
        # apple/container's signed installer puts `container` in /usr/local/bin
        # (see apple-container/scripts/install.sh), which launchd's PATH lacks.
        export PATH="${userBin}:/usr/local/bin:$PATH"
        set -euo pipefail
        start=$(date +%s)
        echo "kiac-resume: start $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        record() {
          rc=$?
          out="${textfileDir}/kiac_resume.prom"
          cat > "$out.tmp" <<EOF
        # HELP kiac_resume_exit_code Exit code of the last kiac-resume run.
        # TYPE kiac_resume_exit_code gauge
        kiac_resume_exit_code $rc
        # HELP kiac_resume_start_timestamp_seconds Start time of the last kiac-resume run.
        # TYPE kiac_resume_start_timestamp_seconds gauge
        kiac_resume_start_timestamp_seconds $start
        # HELP kiac_resume_end_timestamp_seconds End time of the last kiac-resume run.
        # TYPE kiac_resume_end_timestamp_seconds gauge
        kiac_resume_end_timestamp_seconds $(date +%s)
        EOF
          mv "$out.tmp" "$out"
          echo "kiac-resume: exit $rc after $(( $(date +%s) - start ))s"
        }
        trap record EXIT
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

    launchd.user.agents.kiac-health = {
      serviceConfig = {
        RunAtLoad = true;
        StartInterval = 60;
        StandardOutPath = "/var/log/kiac-health.log";
        StandardErrorPath = "/var/log/kiac-health.log";
      };
      script = ''
        export PATH="${userBin}:/usr/local/bin:$PATH"
        set -u
        t="${pkgs.coreutils}/bin/timeout 20"
        kc="kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml"
        runtime=0 ready=0 dns=0 total=0 bad=0
        if $t container system status 2>/dev/null | grep -q '^status *running'; then
          runtime=1
          r=$($t container exec ${node} $kc get node ${node} \
            -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
          [ "$r" = True ] && ready=1
          phases=$($t container exec ${node} $kc get pods -n kube-system \
            -o jsonpath='{range .items[*]}{.status.phase}{"\n"}{end}' 2>/dev/null)
          total=$(printf '%s\n' "$phases" | grep -c .)
          bad=$(printf '%s\n' "$phases" | grep . | grep -cvxE 'Running|Succeeded')
          $t container exec ${node} nslookup registry-1.docker.io >/dev/null 2>&1 && dns=1
        fi
        out="${textfileDir}/kiac_health.prom"
        cat > "$out.tmp" <<EOF
        # HELP kiac_health_probe_timestamp_seconds Time of the last kiac-health probe.
        # TYPE kiac_health_probe_timestamp_seconds gauge
        kiac_health_probe_timestamp_seconds $(date +%s)
        # HELP kiac_runtime_up Whether apple/container's runtime reports running.
        # TYPE kiac_runtime_up gauge
        kiac_runtime_up $runtime
        # HELP kiac_node_ready Whether the homelab node's Ready condition is True.
        # TYPE kiac_node_ready gauge
        kiac_node_ready $ready
        # HELP kiac_node_dns_ok Whether DNS resolution works inside the node.
        # TYPE kiac_node_dns_ok gauge
        kiac_node_dns_ok $dns
        # HELP kiac_kube_system_pods Number of kube-system pods.
        # TYPE kiac_kube_system_pods gauge
        kiac_kube_system_pods $total
        # HELP kiac_kube_system_pods_not_running kube-system pods not Running or Succeeded.
        # TYPE kiac_kube_system_pods_not_running gauge
        kiac_kube_system_pods_not_running $bad
        EOF
        mv "$out.tmp" "$out"
      '';
    };
  };
}
