{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.monitoring;
  composeFile = ./compose.yaml;
  prometheusConfig = ./prometheus.yml;
  lokiConfig = ./loki-config.yml;
  alloyConfig = ./alloy-config.alloy;
  grafanaProvisioningDir = ./grafana/provisioning;
in
{
  options.services.monitoring = {
    enable = mkEnableOption "Monitoring stack";

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/monitoring";
      description = "Base directory for monitoring data storage on the host.";
    };
  };

  config = mkIf cfg.enable {
    environment.etc."newsyslog.d/monitoring.conf".text = ''
      # logfilename          [owner:group]  mode  count  size  when  flags
      /var/log/monitoring.log                644   7      10240 *     GZ
    '';

    environment.etc."caddy/sites/grafana.caddy".text = ''
      https://grafana.${config.networking.hostName}.internal {
        import internal_tls
        reverse_proxy 127.0.0.1:3000
      }
    '';

    environment.etc."caddy/sites/prometheus.caddy".text = ''
      https://prometheus.${config.networking.hostName}.internal {
        import internal_tls
        reverse_proxy 127.0.0.1:9090
      }
    '';

    sops.secrets.grafana_admin_password = {
      sopsFile = ./secrets.yaml;
    };

    launchd.daemons.monitoring-compose = {
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/var/log/monitoring.log";
        StandardErrorPath = "/var/log/monitoring.log";
      };
      script = ''
        until ${pkgs.docker}/bin/docker info >/dev/null 2>&1; do
          echo "Waiting for Docker to be ready..."
          sleep 5
        done

        export GRAFANA_ADMIN_PASSWORD=$(cat ${config.sops.secrets.grafana_admin_password.path})
        export MONITORING_DATA_DIR="${cfg.dataDir}"
        export PROMETHEUS_CONFIG="${prometheusConfig}"
        export LOKI_CONFIG="${lokiConfig}"
        export ALLOY_CONFIG="${alloyConfig}"
        export GRAFANA_PROVISIONING_DIR="${grafanaProvisioningDir}"

        mkdir -p "$MONITORING_DATA_DIR/prometheus" \
                 "$MONITORING_DATA_DIR/grafana" \
                 "$MONITORING_DATA_DIR/loki"
        chmod -R 777 "$MONITORING_DATA_DIR"

        exec ${pkgs.docker-compose}/bin/docker-compose \
          -f ${composeFile} \
          up --no-build --force-recreate
      '';
    };
  };
}
