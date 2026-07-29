{ config, lib, ... }:

/*
  Usage:
  custom.syncHomeFiles.enable = true;
  # custom.syncHomeFiles.targetDir = "..."; # Optional: defaults to ~/repositories/github.com/ccycle/dotfiles/home-files
  custom.syncHomeFiles.files = [
  ".zshrc"
  ".config/git/config"
  # Add other files you want to sync
  ];
  custom.syncHomeFiles.directories = [
  ".config/some-dir"
  ];
*/

with lib;

let
  cfg = config.custom.syncHomeFiles;
in
{
  options.custom.syncHomeFiles = {
    enable = mkEnableOption "Sync specific home-manager files to a local directory";

    targetDir = mkOption {
      type = types.str;
      default = "${config.custom.dotfiles.dir}/home-files";
      description = "Directory where the files should be copied to.";
    };

    files = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "List of files relative to HOME to copy.";
    };

    directories = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "List of directories relative to HOME to copy.";
    };
  };

  config = mkIf cfg.enable {
    home.activation.syncHomeFiles = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      # Expand tilde at the start of the path explicitly
      target_dir="${cfg.targetDir}"
      if [[ "$target_dir" == ~* ]]; then
        target_dir="$HOME''${target_dir:1}"
      fi

      echo "Syncing home files to $target_dir..."
      mkdir -p "$target_dir"

      paths=(
        ${builtins.concatStringsSep "\n" (map (f: "\"${f}\"") (cfg.files ++ cfg.directories))}
      )

      for path in "''${paths[@]}"; do
        src="${config.home.homeDirectory}/$path"
        dest="$target_dir/$path"
        dest_dir=$(dirname "$dest")

        if [ -e "$src" ]; then
          mkdir -p "$dest_dir"
          
          # Remove destination to ensure clean copy (avoid cp merging directories)
          if [ -e "$dest" ]; then
            rm -rf "$dest"
          fi

          # Copy dereferencing symlinks (-L), recursive (-r) for directories
          cp -Lr "$src" "$dest"
          
          # Ensure writable permissions recursively
          chmod -R u+w "$dest"
          
          echo "Copied $src to $dest"
        else
          echo "Warning: Source file $src does not exist, skipping."
        fi
      done
    '';
  };
}
