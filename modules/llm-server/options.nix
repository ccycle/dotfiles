{ config, lib, pkgs, pkgs-2605, ... }:

with lib;

let
  cfg = config.services.llm-server;
  catalog = builtins.fromJSON (builtins.readFile ./catalog.json);
  waitForMount = import ../../utils/waitForMount.nix;

  modelEntries = mapAttrsToList
    (id: m: {
      inherit id;
      inherit (m) contextLength extraFlags;
      filename = baseNameOf (builtins.head m.files).url;
      files = m.files;
    })
    catalog.models;

  llamaSwapConfig = {
    healthCheckTimeout = 300;
    macros = {
      llama_server = "${pkgs-2605.llama-cpp}/bin/llama-server --host 127.0.0.1 --port \${PORT} --jinja -ngl 99";
    };
    models = listToAttrs (map
      (m: nameValuePair m.id {
        cmd = "\${llama_server} -m ${cfg.modelsDir}/${m.filename} --ctx-size ${toString m.contextLength}"
          + optionalString (m.extraFlags != [ ]) " ${concatStringsSep " " m.extraFlags}";
        ttl = cfg.ttl;
      })
      modelEntries);
  };

  configYaml = (pkgs.formats.yaml { }).generate "llama-swap-config.yaml" llamaSwapConfig;

  downloadScript = concatMapStringsSep "\n"
    (m:
      concatMapStringsSep "\n"
        (f:
          let filename = baseNameOf f.url; in
          ''
            if [ ! -f "${cfg.modelsDir}/${filename}" ]; then
              echo "Downloading ${filename}..."
              ${pkgs.curl}/bin/curl -fL --retry 5 -o "${cfg.modelsDir}/${filename}.part" "${f.url}"
              ${optionalString (f.sha256 != "") ''
                echo "${f.sha256}  ${cfg.modelsDir}/${filename}.part" | shasum -a 256 -c - || {
                  echo "SHA256 mismatch for ${filename}"
                  rm -f "${cfg.modelsDir}/${filename}.part"
                  exit 1
                }
              ''}
              mv "${cfg.modelsDir}/${filename}.part" "${cfg.modelsDir}/${filename}"
              echo "Downloaded ${filename}"
            fi
          ''
        )
        m.files
    )
    modelEntries;
in
{
  options.services.llm-server = {
    enable = mkEnableOption "LLM server (llama-swap + llama-cpp)";

    port = mkOption {
      type = types.port;
      default = 8880;
    };

    modelsDir = mkOption {
      type = types.str;
      default = "/var/lib/llm-server/models";
    };

    mountPoint = mkOption {
      type = types.str;
      default = "";
    };

    ttl = mkOption {
      type = types.int;
      default = 3600;
    };
  };

  config = mkIf cfg.enable {
    services.caddy.portalEntries = [{
      name = "LLM Server";
      url = "https://llm.${config.networking.hostName}.internal";
      descriptionJa = "ローカル LLM 推論サーバー";
      descriptionEn = "Local LLM Inference Server";
      logoSvg = builtins.readFile ./llm-server-logo.svg;
    }];

    environment.etc."caddy/sites/llm-server.caddy".text = ''
      http://llm.${config.networking.hostName}.internal, https://llm.${config.networking.hostName}.internal {
        import internal_tls
        reverse_proxy 127.0.0.1:${toString cfg.port}
      }
    '';

    launchd.user.agents.llm-server = {
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/var/tmp/llm-server.log";
        StandardErrorPath = "/var/tmp/llm-server.log";
      };
      script = ''
        ${optionalString (cfg.mountPoint != "") (waitForMount cfg.mountPoint)}

        mkdir -p "${cfg.modelsDir}"

        ${downloadScript}

        exec ${pkgs.llama-swap}/bin/llama-swap \
          --config ${configYaml} \
          --listen 127.0.0.1:${toString cfg.port}
      '';
    };
  };
}
