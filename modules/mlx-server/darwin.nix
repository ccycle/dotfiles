{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.mlx-server;

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
in
{
  imports = [ ./options.nix ];

  config = mkIf cfg.enable {
    environment.etc."caddy/sites/mlx-server.caddy".text = ''
      http://mlx.${config.networking.hostName}.internal, https://mlx.${config.networking.hostName}.internal {
        import internal_tls
        reverse_proxy 127.0.0.1:${toString cfg.port}
      }
    '';

    launchd.user.agents.mlx-server = {
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/var/tmp/mlx-server.log";
        StandardErrorPath = "/var/tmp/mlx-server.log";
      };
      script = ''
        set -euo pipefail

        mkdir -p "${cfg.modelsDir}"

        exec ${mlxEnv}/bin/python3 -m mlx_lm server \
          --model "${cfg.defaultModel}" \
          --host 127.0.0.1 \
          --port ${toString cfg.port}
      '';
    };
  };
}
