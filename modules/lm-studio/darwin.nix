{ pkgs, ... }:
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
{
  environment.systemPackages = [ lm-studio ];
}
