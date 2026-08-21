{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.monitoring;
  # Directory where periodic textfile collectors (e.g. the static-reports
  # du job below) drop .prom files for node_exporter to expose on :9100.
  nodeExporterTextfileDir = "/var/lib/node-exporter-textfile";
  composeFile = ./compose.yaml;
  waitForMount = import ../../utils/waitForMount.nix;
  prometheusConfig = ./prometheus.yml;
  prometheusRules = ./prometheus-rules.yml;
  lokiConfig = ./loki-config.yml;
  alloyConfig = ./alloy-config.alloy;
  grafanaProvisioningDir = ./grafana/provisioning;
  grafanaDashboardsDir = ./grafana/dashboards;
in
{
  options.services.monitoring = {
    enable = mkEnableOption "Monitoring stack";

    prometheusAuthHash = mkOption {
      type = types.str;
      default = "";
      description = ''
        bcrypt hash for Prometheus basic auth. Generate with:
        nix run nixpkgs#caddy -- hash-password --plaintext <PASSWORD>
        Set to empty string to disable auth.
      '';
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/monitoring";
      description = "Base directory for Prometheus and Loki data storage on the host.";
    };

    grafanaDataVolume = mkOption {
      type = types.str;
      default = "grafana-data";
      description = "Docker named volume holding Grafana's SQLite database and plugins. A named volume lives on VM-internal storage (not virtiofs), which is what SQLite requires; see design.md.";
    };

    gitlabLogsDir = mkOption {
      type = types.str;
      default = "";
      description = "GitLab host log directory to collect into Loki. Empty disables collection.";
    };

    mountPoint = mkOption {
      type = types.str;
      default = "";
      description = "If set, wait for this volume to be mounted before starting (e.g. /Volumes/<YOUR_DRIVE>).";
    };
  };

  config = mkIf cfg.enable {
    services.caddy.portalEntries = [
      {
        name = "Grafana";
        url = "https://grafana.${config.networking.hostName}.internal";
        descriptionJa = "ダッシュボード＆可視化";
        descriptionEn = "Dashboards & Visualization";
        logoSvg = builtins.readFile ./grafana-logo.svg;
      }
      {
        name = "Prometheus";
        url = "https://prometheus.${config.networking.hostName}.internal";
        descriptionJa = "モニタリングシステム";
        descriptionEn = "Monitoring System";
        logoSvg = builtins.readFile ./prometheus-logo.svg;
      }
    ];

    environment.etc."newsyslog.d/monitoring.conf".text = ''
      # logfilename          [owner:group]  mode  count  size  when  flags
      /var/log/monitoring.log                644   7      10240 *     GZ
    '';

    environment.etc."caddy/sites/grafana.caddy".text = ''
      https://grafana.${config.networking.hostName}.internal {
        import internal_tls
        reverse_proxy 127.0.0.1:3200
      }
    '';

    environment.etc."caddy/sites/prometheus.caddy".text = ''
      https://prometheus.${config.networking.hostName}.internal {
        import internal_tls
        ${lib.optionalString (cfg.prometheusAuthHash != "") "basicauth / prometheus ${cfg.prometheusAuthHash}"}
        reverse_proxy 127.0.0.1:9090
      }
    '';

    # Confidential OIDC client registered on Pocket ID. The client secret is
    # captured by scripts/pocket-id-register-clients.sh; the client ID is
    # fixed (plaintext) and matches GRAFANA_OIDC_CLIENT_ID below.
    services.pocket-id.oidcClients = [{
      name = "Grafana";
      clientId = "grafana";
      isPublic = false;
      pkceEnabled = false;
      callbackURLs = [ "https://grafana.${config.networking.hostName}.internal/login/generic_oauth" ];
      logoutCallbackURLs = [ "https://grafana.${config.networking.hostName}.internal/login/generic_oauth" ];
      secretFile = "modules/monitoring/secrets-${config.networking.hostName}.yaml";
      secretKey = "grafana_oidc_client_secret";
      allowedGroups = [ "grafana_admins" ];
    }];

    # Pocket ID group for Grafana access control. Only members of this
    # group can log in to Grafana via OIDC (enforced by allowedGroups
    # on the client above).
    services.pocket-id.oidcGroups = [{
      name = "grafana_admins";
      friendlyName = "Grafana Admins";
    }];

    sops.secrets.grafana_admin_password = {
      sopsFile = ./secrets-${config.networking.hostName}.yaml;
    };
    sops.secrets.grafana_oidc_client_secret = {
      sopsFile = ./secrets-${config.networking.hostName}.yaml;
    };

    # CLI query tools for log/metrics investigation (see the
    # investigate-service skill): logcli from grafana-loki, promtool
    # from prometheus.
    environment.systemPackages = [
      pkgs.grafana-loki
      pkgs.prometheus
    ];

    # Host-level (macOS) metrics: node_exporter runs as a native launchd
    # daemon (loopback-only on 9100), NOT inside the Docker stack — a Linux
    # container via OrbStack would only observe the container/VM's own
    # filesystem, not the true host APFS volumes. Same pattern as atticd.
    launchd.daemons.node-exporter = {
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/var/log/node-exporter.log";
        StandardErrorPath = "/var/log/node-exporter.log";
      };
      script = ''
        mkdir -p ${nodeExporterTextfileDir}
        exec ${pkgs.prometheus-node-exporter}/bin/node_exporter \
          --web.listen-address=127.0.0.1:9100 \
          --collector.textfile.directory=${nodeExporterTextfileDir}
      '';
    };

    # Directory-specific size metric for /var/lib/static-reports (the
    # question is "is reports/ accumulating over time?"), which the
    # whole-volume node_filesystem_* metrics cannot answer directly. Runs
    # regularly, writing a .prom file into node_exporter's textfile dir for
    # the next scrape to pick up. Opt-in per-directory via staticReports
    # enabling; consumers of static-reports could add siblings here.
    launchd.daemons.static-reports-size = lib.mkIf config.services.staticReports.enable {
      serviceConfig = {
        RunAtLoad = true;
        StartInterval = 300;
        StandardOutPath = "/var/log/static-reports-size.log";
        StandardErrorPath = "/var/log/static-reports-size.log";
      };
      script = ''
        DIR="${config.services.staticReports.dataDir}"
        OUT="${nodeExporterTextfileDir}"
        if [ ! -d "$DIR" ]; then
          exit 0
        fi
        SIZE=$(${pkgs.coreutils}/bin/du -sb "$DIR" | ${pkgs.coreutils}/bin/awk '{print $1}')
        cat > "$OUT/static_reports_size_bytes.prom".tmp <<EOF
        # HELP static_reports_size_bytes Size of the static-reports dataDir in bytes.
        # TYPE static_reports_size_bytes gauge
        static_reports_size_bytes $SIZE
        EOF
        ${pkgs.coreutils}/bin/mv "$OUT/static_reports_size_bytes.prom".tmp "$OUT/static_reports_size_bytes.prom"
      '';
    };

    launchd.daemons.monitoring-compose = {
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/var/log/monitoring.log";
        StandardErrorPath = "/var/log/monitoring.log";
      };
      script = ''
        ${optionalString (cfg.mountPoint != "") (waitForMount cfg.mountPoint)}

        until ${pkgs.docker}/bin/docker info >/dev/null 2>&1; do
          echo "Waiting for Docker to be ready..."
          sleep 5
        done

        export GRAFANA_ADMIN_PASSWORD=$(cat ${config.sops.secrets.grafana_admin_password.path})
        export GRAFANA_OIDC_CLIENT_ID="grafana"
        export GRAFANA_OIDC_CLIENT_SECRET=$(cat ${config.sops.secrets.grafana_oidc_client_secret.path})
        export GRAFANA_OIDC_ISSUER="https://auth.${config.networking.hostName}.internal"
        export MONITORING_DATA_DIR="${cfg.dataDir}"
        export PROMETHEUS_CONFIG="${prometheusConfig}"
        export PROMETHEUS_RULES="${prometheusRules}"
        export LOKI_CONFIG="${lokiConfig}"
        export ALLOY_CONFIG="${alloyConfig}"
        export GRAFANA_PROVISIONING_DIR="${grafanaProvisioningDir}"
        export GRAFANA_DASHBOARDS_DIR="${grafanaDashboardsDir}"
        export GRAFANA_ROOT_URL="https://grafana.${config.networking.hostName}.internal"
        export GITLAB_LOGS_DIR="${cfg.gitlabLogsDir}"

        mkdir -p "$MONITORING_DATA_DIR/prometheus" \
                 "$MONITORING_DATA_DIR/loki"
        chmod -R 777 "$MONITORING_DATA_DIR"

        exec ${pkgs.docker-compose}/bin/docker-compose \
          -f ${composeFile} \
          up --no-build --force-recreate
      '';
    };
  };
}
