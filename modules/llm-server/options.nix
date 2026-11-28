{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.llm-server;
  catalog = builtins.fromJSON (builtins.readFile ./catalog.json);
  waitForMount = import ../../utils/waitForMount.nix;
  ollama = import ./drv.nix { inherit pkgs lib; };

  # Ollama has one server-wide context length; per-model values in the
  # catalog only cap what clients ask for, so the server must hold the
  # largest of them.
  contextLength = foldl' max 0 (mapAttrsToList (_: m: m.contextLength) catalog.models);

  # Registry models are a plain `ollama pull`. Models with a `source` are
  # bf16 MLX safetensors repos on Hugging Face that have no Ollama registry
  # build: they are downloaded to a scratch dir inside modelsDir (the only
  # place guaranteed to have room for a ~70 GB bf16 checkpoint) and
  # quantized locally by `ollama create`, then the scratch copy is dropped.
  provisionModel =
    id: m:
    if m ? source then
      let
        repo = m.source.huggingface;
        scratch = "${cfg.modelsDir}/.hf-import/${replaceStrings [ "/" ] [ "--" ] repo}";
      in
      ''
        if ! ollama show ${escapeShellArg id} >/dev/null 2>&1; then
          echo "Importing ${repo} as ${id}..."
          mkdir -p "${scratch}"
          ${pkgs.curl}/bin/curl -fsSL "https://huggingface.co/api/models/${repo}" \
            | ${pkgs.jq}/bin/jq -r '.siblings[].rfilename' \
            | while read -r f; do
                mkdir -p "${scratch}/$(dirname "$f")"
                ${pkgs.curl}/bin/curl -fL --retry 5 -C - -o "${scratch}/$f" \
                  "https://huggingface.co/${repo}/resolve/main/$f"
              done
          printf 'FROM %s\n' "${scratch}" > "${scratch}/Modelfile"
          ollama create ${escapeShellArg id} -q ${m.source.quantize} -f "${scratch}/Modelfile"
          rm -rf "${scratch}"
        fi
      ''
    else
      ''
        ollama show ${escapeShellArg id} >/dev/null 2>&1 || ollama pull ${escapeShellArg id}
      '';
in
{
  options.services.llm-server = {
    enable = mkEnableOption "LLM server (Ollama with its MLX runner)";

    port = mkOption {
      type = types.port;
      default = 11434;
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
      description = "Seconds an idle model stays loaded (OLLAMA_KEEP_ALIVE).";
    };
  };

  config = mkIf cfg.enable {
    # The CLI talks to 127.0.0.1:11434 unless OLLAMA_HOST says otherwise.
    environment.systemPackages = [ ollama ];

    services.caddy.portalEntries = [
      {
        name = "LLM Server";
        url = "https://llm.${config.networking.hostName}.internal";
        descriptionJa = "ローカル LLM 推論サーバー";
        descriptionEn = "Local LLM Inference Server";
        logoSvg = builtins.readFile ./llm-server-logo.svg;
        alwaysOn = true;
      }
    ];

    # Ollama's DNS-rebinding guard accepts *.internal Host headers, so the
    # vhost name passes through unchanged.
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

        export OLLAMA_HOST=127.0.0.1:${toString cfg.port}
        export OLLAMA_MODELS="${cfg.modelsDir}"
        export OLLAMA_CONTEXT_LENGTH=${toString contextLength}
        export OLLAMA_KEEP_ALIVE=${toString cfg.ttl}s
        export OLLAMA_MAX_LOADED_MODELS=1
        export OLLAMA_NO_CLOUD=1
        exec ${ollama}/bin/ollama serve
      '';
    };

    # Separate one-shot agent so a multi-hour first download never holds up
    # (or gets killed with) the server itself. Exiting non-zero makes
    # launchd retry; a clean exit means every catalog model is present.
    launchd.user.agents.llm-server-models = {
      serviceConfig = {
        KeepAlive.SuccessfulExit = false;
        RunAtLoad = true;
        StandardOutPath = "/var/tmp/llm-server-models.log";
        StandardErrorPath = "/var/tmp/llm-server-models.log";
      };
      path = [
        ollama
        pkgs.coreutils
      ];
      script = ''
        set -euo pipefail
        export OLLAMA_HOST=127.0.0.1:${toString cfg.port}
        export OLLAMA_MODELS="${cfg.modelsDir}"
        until ${pkgs.curl}/bin/curl -sf "http://$OLLAMA_HOST/api/version" >/dev/null; do sleep 5; done

        ${concatStringsSep "\n" (mapAttrsToList provisionModel catalog.models)}
        echo "All catalog models present."
      '';
    };
  };
}
