{ pkgs, ... }:
let
  lm-studio = pkgs.brewCasks.lm-studio.overrideAttrs (old: {
    # The DMG is APFS-based, so undmg and unzip both fail and 7zz is used
    # as fallback. 7zz refuses to extract a symlink that points through
    # another symlink ("Dangerous link via another link"). We let 7zz skip
    # those links and recreate the missing one manually afterwards.
    unpackPhase = ''
      undmg $src || unzip $src || 7zz x -snld $src || true

      # 7zz skips "dangerous" chained symlinks; recreate the missing one.
      local target="LM Studio.app/Contents/Resources/app/.webpack/bin/extensions/backends/vendor/_amphibian/app-mlx-generate-mac14-arm64@1/bin"
      if [[ -d "$target" && ! -e "$target/python3.11" ]]; then
        ln -s python "$target/python3.11"
      fi
    '';
  });
in
{
  environment.systemPackages = [ lm-studio ];
}
