{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.mtplx;
  catalog = builtins.fromJSON (builtins.readFile ./catalog.json);
  modelEntries = mapAttrsToList (id: m: { inherit id; } // m) catalog.models;

  dmgUrl = "https://github.com/youssofal/MTPLX/releases/download/v${cfg.dmgVersion}/MTPLX-${cfg.dmgVersion}.dmg";

  # The DMG ships a full GUI .app (Sparkle auto-updater, hardware wizard).
  # We only want its bundled headless Python runtime + the mtplx wheel, so we
  # extract those two paths and discard the rest of the bundle.
  installScript = ''
    INSTALL_DIR="${cfg.installDir}"
    RUNTIME_BIN="$INSTALL_DIR/PythonRuntime/bin"

    if [ ! -x "$RUNTIME_BIN/mtplx" ]; then
      echo "Installing MTPLX ${cfg.dmgVersion}..."
      TMP_DMG="$(${pkgs.coreutils}/bin/mktemp -t mtplx-dmg-XXXXXX).dmg"
      ${pkgs.curl}/bin/curl -fL --retry 5 -o "$TMP_DMG" "${dmgUrl}"
      echo "${cfg.dmgSha256}  $TMP_DMG" | shasum -a 256 -c - || {
        echo "SHA256 mismatch for MTPLX-${cfg.dmgVersion}.dmg"
        rm -f "$TMP_DMG"
        exit 1
      }

      MOUNT_DIR="$(${pkgs.coreutils}/bin/mktemp -d -t mtplx-mount-XXXXXX)"
      hdiutil attach "$TMP_DMG" -nobrowse -readonly -mountpoint "$MOUNT_DIR" -quiet

      mkdir -p "$INSTALL_DIR"
      rm -rf "$INSTALL_DIR/PythonRuntime" "$INSTALL_DIR"/mtplx-*-py3-none-any.whl
      cp -R "$MOUNT_DIR/MTPLX.app/Contents/Resources/PythonRuntime" "$INSTALL_DIR/PythonRuntime"
      cp "$MOUNT_DIR/MTPLX.app/Contents/Resources/Runtime/"mtplx-*-py3-none-any.whl "$INSTALL_DIR/"

      hdiutil detach "$MOUNT_DIR" -quiet
      rm -f "$TMP_DMG"
      rmdir "$MOUNT_DIR" || true

      # Resolves mlx/mlx-lm/fastapi/etc fresh from PyPI, satisfying mtplx's
      # own version pins (nixpkgs' mlx is older than mtplx requires).
      "$RUNTIME_BIN/python3" -m pip install --quiet "$INSTALL_DIR"/mtplx-*-py3-none-any.whl
      echo "MTPLX installed."
    fi
  '';
in
{
  imports = [ ./options.nix ];

  config = mkIf cfg.enable {
    services.caddy.portalEntries = [
      {
        name = "MTPLX";
        url = "https://mtplx.${config.networking.hostName}.internal";
        descriptionJa = "MTPLX ローカル推論サーバー (MLX / 投機的デコーディング)";
        descriptionEn = "MTPLX Local Inference Server (MLX / speculative decoding)";
        logoSvg = builtins.readFile ./mtplx-logo.svg;
      }
    ];

    environment.etc."caddy/sites/mtplx.caddy".text = ''
      http://mtplx.${config.networking.hostName}.internal, https://mtplx.${config.networking.hostName}.internal {
        import internal_tls
        reverse_proxy 127.0.0.1:${toString cfg.port}
      }
    '';

    # One launchd agent per catalog model, all bound to the same port: mtplx
    # has no idle-unload, and this machine doesn't have headroom to hold two
    # of these models resident at once (see design.md). Each is a separate
    # job (KeepAlive/RunAtLoad off, start manually via the
    # `mtplx-start-<shortId>`/`mtplx-stop-<shortId>` aliases in ./home.nix)
    # so starting a second one while the first is still running fails fast
    # on a port conflict rather than silently doubling memory use.
    launchd.user.agents = listToAttrs (
      map (
        model:
        nameValuePair "mtplx-${model.shortId}" {
          serviceConfig = {
            KeepAlive = false;
            RunAtLoad = false;
            StandardOutPath = "/var/tmp/mtplx-${model.shortId}.log";
            StandardErrorPath = "/var/tmp/mtplx-${model.shortId}.log";
          };
          script = ''
            set -euo pipefail

            ${installScript}

            # "turbo" is mtplx's fastest profile that still supports our full
            # context window; "performance-cold" is faster still but caps out
            # at ~8K context, too short for opencode's system prompt.
            exec "${cfg.installDir}/PythonRuntime/bin/mtplx" serve \
              --model "${model.hfRepo}" \
              --download \
              --host 127.0.0.1 \
              --port ${toString cfg.port} \
              --no-auth \
              --profile turbo \
              --model-id "${model.id}" \
              --context-window ${toString model.contextLength}${
                optionalString ((model.extraFlags or [ ]) != [ ]) " ${concatStringsSep " " model.extraFlags}"
              }
          '';
        }
      ) modelEntries
    );
  };
}
