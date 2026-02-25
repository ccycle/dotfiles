{ pkgs, ... }:

{
  launchd.daemons.opencloud = {
    serviceConfig = {
      KeepAlive = true;
      RunAtLoad = true;
      StandardOutPath = "/var/log/opencloud.log";
      StandardErrorPath = "/var/log/opencloud.log";
      EnvironmentVariables = {
        OC_BASE_DATA_PATH = "/var/lib/opencloud";
        OC_CONFIG_DIR = "/var/lib/opencloud/config";
        OPENCLOUD_URL = "https://opencloud.mac-mini-m4.internal";
        PROXY_HTTP_ADDR = "127.0.0.1:9200";
        # Disable TLS for internal proxying as Caddy handles it
        PROXY_TRANSPORT_TLS = "false";
        OC_INSECURE = "true";
      };
    };
    script = ''
      mkdir -p /var/lib/opencloud
      
      # Initialize config if not exists
      if [ ! -f /var/lib/opencloud/config/opencloud.yaml ]; then
        ${pkgs.opencloud}/bin/opencloud init --insecure true --config-path /var/lib/opencloud/config
      fi

      exec ${pkgs.opencloud}/bin/opencloud server
    '';
  };
}
