{ config, lib, pkgs, ... }:

let
  cfg = config.custom.lm-studio;
in
{
  imports = [
    ./options.nix
  ];

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      environment.systemPackages =
        let
          lm-studio = pkgs.brewCasks.lm-studio.overrideAttrs (old: {
            # The DMG is APFS-based, so undmg and unzip both fail and 7zz is used
            # as fallback. Two issues must be fixed:
            #
            # 1. 7zz extracts APFS alternate data streams (code-signing xattrs) as
            #    regular files with ":" in their names, which breaks the code
            #    signature seal. Pass -sns- to suppress alternate stream extraction.
            #
            # 2. 7zz skips "dangerous" chained symlinks (a symlink pointing through
            #    another symlink) and creates an empty file instead. We detect this
            #    and recreate the missing python3.11 symlink.
            unpackPhase = ''
              undmg $src || unzip $src || 7zz x -snld -sns- $src || true

              # 7zz skips "dangerous" chained symlinks; recreate the missing one.
              local target="LM Studio.app/Contents/Resources/app/.webpack/bin/extensions/backends/vendor/_amphibian/app-mlx-generate-mac14-arm64@1/bin"
              if [[ -d "$target" && -f "$target/python3.11" && ! -s "$target/python3.11" ]]; then
                rm "$target/python3.11"
                ln -s python "$target/python3.11"
              fi
            '';
          });
        in
        [ lm-studio ];
    })

    (lib.mkIf cfg.server.enable {
      # HTTP on purpose: Tailscale WireGuard encrypts transport; plain HTTP
      # avoids internal-CA trust setup in Bun-based clients (opencode).
      environment.etc."caddy/sites/lm-studio.caddy".text = ''
        http://llm.${config.networking.hostName}.internal {
          reverse_proxy 127.0.0.1:1234
        }
      '';

      launchd.user.agents.lm-studio-server = {
        serviceConfig = {
          RunAtLoad = true;
          KeepAlive = false;
          StandardOutPath = "/var/tmp/lm-studio-server.log";
          StandardErrorPath = "/var/tmp/lm-studio-server.log";
        };
        script = ''
          LMS="$HOME/.lmstudio/bin/lms"
          if [ ! -x "$LMS" ]; then
            echo "lms not found; launch LM Studio once, then: launchctl kickstart gui/$(id -u)/org.nixos.lm-studio-server"
            exit 0
          fi
          exec "$LMS" server start --port 1234
        '';
      };
    })
  ];
}
