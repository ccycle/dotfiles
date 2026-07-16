{ config, lib, pkgs, ... }:

let
  cfg = config.custom.lm-studio;
in
{
  imports = [
    ./options.nix
  ];

  config = lib.mkIf cfg.enable {
    environment.systemPackages =
      let
        lm-studio = pkgs.brewCasks.lm-studio.overrideAttrs (old: {
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
  };
}
