{ config, lib, ... }:

let
  vol = config.custom.storage.volumeRoot;
in
{
  options.custom.storage = {
    volumeRoot = lib.mkOption {
      type = lib.types.str;
      default = "";
    };
  };

  config = {
    assertions =
      let
        hint = "Run: scripts/setup-local-storage.sh /Volumes/<YOUR_DRIVE>";
        require = svc: {
          assertion = config.services.${svc}.enable -> vol != "";
          message = "services.${svc} requires custom.storage.volumeRoot to be set. ${hint}";
        };
      in
      map require [ "immich" "opencloud" "gitlab" "monitoring" ];
  };
}
