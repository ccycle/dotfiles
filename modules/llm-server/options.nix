{
  config,
  lib,
  pkgs,
  pkgs-2605,
  ...
}:

with lib;

let
  cfg = config.services.llm-server;
  catalog = builtins.fromJSON (builtins.readFile ./catalog.json);
  waitForMount = import ../../utils/waitForMount.nix;

  # nixpkgs builds python3Packages.mlx with MLX_BUILD_METAL=false: the `metal`
  # shader compiler is closed-source and can't run inside the Nix sandbox, so
  # nixpkgs's mlx is CPU-only (see pkgs/development/python-modules/mlx/default.nix).
  # Apple's own PyPI release CI builds real Metal-enabled wheels instead, so we
  # substitute those prebuilt wheels for the `mlx` package rather than building
  # from source. mlx-lm and other dependents pick this up automatically since
  # the override happens at the python package-set fixpoint.
  # Apple splits the PyPI release across two wheels sharing one `mlx/`
  # namespace: `mlx` ships the frontend (core.*.so, pure-Python nn/optimizers),
  # `mlx-metal` ships the compiled backend (libmlx.dylib, the precompiled
  # mlx.metallib shader library). A plain `pip install mlx` unpacks both into
  # the same site-packages/mlx directory. Two separate Nix derivations would
  # each get their own store path, so core.so's `@rpath/libmlx.dylib` lookup
  # (relative to its own directory) would never find the backend's dylib.
  # We therefore unpack both wheels into a single derivation's output.
  mlxWheelVersion = "0.31.2";
  mlxMetalWheel = pkgs.fetchurl {
    url = "https://files.pythonhosted.org/packages/4f/5d/4c690d5b93c30ba002656c37363159d978705bf8eb801b8481840fb942c2/mlx_metal-${mlxWheelVersion}-py3-none-macosx_15_0_arm64.whl";
    hash = "sha256-6dTl/ObKEKh6DjiFl/mVGa1ZTQnmdHCLUxK9i9T1mX0=";
  };
  metalPython = pkgs.python3.override {
    packageOverrides = pyFinal: pyPrev: {
      mlx = pyFinal.buildPythonPackage {
        pname = "mlx";
        version = mlxWheelVersion;
        format = "wheel";
        src = pkgs.fetchurl {
          url = "https://files.pythonhosted.org/packages/dd/14/e9cd18b51f9e1dbcb060eec0fafc2d2428c8e1eacd9b0a02d7c5ce75b661/mlx-${mlxWheelVersion}-cp313-cp313-macosx_15_0_arm64.whl";
          hash = "sha256-NLAXHNnrXEP92CCR9hNdbMxaBlNjpKPmj6xk+05T03w=";
        };
        nativeBuildInputs = [ pkgs.unzip ];
        postInstall = ''
          unzip -o ${mlxMetalWheel} 'mlx/lib/*' -d $out/${pyFinal.python.sitePackages}
        '';
        doCheck = false;
        # The wheel's own metadata lists mlx-metal as a dependency; since we
        # merge its files in directly rather than keeping it as a separate
        # propagated package, nixpkgs's own dependency-presence check would
        # otherwise fail even though the files are actually present.
        dontCheckRuntimeDeps = true;
        meta.platforms = lib.platforms.darwin;
      };
    };
  };
  mlxEnv = metalPython.withPackages (
    ps: with ps; [
      mlx-lm
      mlx
    ]
  );

  modelEntries = mapAttrsToList (id: m: {
    inherit id;
    inherit (m) contextLength;
    extraFlags = m.extraFlags or [ ];
    backend = m.backend or "llama-cpp";
    files = m.files or [ ];
    filename = if (m.files or [ ]) != [ ] then baseNameOf (builtins.head m.files).url else null;
  }) catalog.models;

  llamaSwapConfig = {
    healthCheckTimeout = 300;
    macros = {
      llama_server = "${pkgs-2605.llama-cpp}/bin/llama-server --host 127.0.0.1 --port \${PORT} --jinja -ngl 99";
      mlx_server = "${mlxEnv}/bin/python3 -m mlx_lm server --host 127.0.0.1 --port \${PORT}";
    };
    models = listToAttrs (
      map (
        m:
        nameValuePair m.id {
          cmd =
            if m.backend == "mlx" then
              "\${mlx_server} --model ${m.id}"
            else
              "\${llama_server} -m ${cfg.modelsDir}/${m.filename} --ctx-size ${toString m.contextLength}"
              + optionalString (m.extraFlags != [ ]) " ${concatStringsSep " " m.extraFlags}";
          ttl = cfg.ttl;
        }
      ) modelEntries
    );
  };

  configYaml = (pkgs.formats.yaml { }).generate "llama-swap-config.yaml" llamaSwapConfig;

  downloadScript = concatMapStringsSep "\n" (
    m:
    concatMapStringsSep "\n" (
      f:
      let
        filename = baseNameOf f.url;
      in
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
    ) m.files
  ) modelEntries;
in
{
  options.services.llm-server = {
    enable = mkEnableOption "LLM server (llama-swap + llama-cpp + mlx-lm)";

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
    services.caddy.portalEntries = [
      {
        name = "LLM Server";
        url = "https://llm.${config.networking.hostName}.internal";
        descriptionJa = "ローカル LLM 推論サーバー";
        descriptionEn = "Local LLM Inference Server";
        logoSvg = builtins.readFile ./llm-server-logo.svg;
      }
    ];

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
