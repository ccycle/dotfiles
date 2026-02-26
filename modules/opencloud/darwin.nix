{ pkgs, config, ... }:

{
  sops.secrets.opencloud_admin_password = {
    sopsFile = ./secrets.yaml;
  };

  launchd.daemons.opencloud = {
    serviceConfig = {
      KeepAlive = true;
      RunAtLoad = true;
      StandardOutPath = "/var/log/opencloud.log";
      StandardErrorPath = "/var/log/opencloud.log";
      EnvironmentVariables = {
        OC_BASE_DATA_PATH = "/var/lib/opencloud";
        OC_CONFIG_DIR = "/var/lib/opencloud/config";
        OC_URL = "https://opencloud.mac-mini-m4.internal";
        PROXY_HTTP_ADDR = "127.0.0.1:9200";
        OC_INSECURE = "true";
        # Disable TLS on the proxy listener; Caddy handles TLS termination
        PROXY_TLS = "false";
        IDP_ASSET_PATH = "${pkgs.opencloud.idp-web}/assets";
        WEB_ASSET_CORE_PATH = "${pkgs.opencloud.web}";
      };
    };
    script = ''
      mkdir -p /var/lib/opencloud

      # Initialize config if not exists
      if [ ! -f /var/lib/opencloud/config/opencloud.yaml ]; then
        export IDM_ADMIN_PASSWORD=$(cat ${config.sops.secrets.opencloud_admin_password.path})
        ${pkgs.opencloud}/bin/opencloud init --insecure true --config-path /var/lib/opencloud/config
      fi

      exec ${pkgs.opencloud}/bin/opencloud server
    '';
  };
}
