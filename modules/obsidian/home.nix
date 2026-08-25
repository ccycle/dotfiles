{
  config,
  lib,
  pkgs,
  ...
}:

let
  vaults = config.obsidian.vaults;
  enableCheck = config.obsidian.enable && vaults != [ ];
in
{
  options = {
    obsidian = {
      enable = lib.mkEnableOption "Obsidian integration";
      vaults = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Paths to your Obsidian vaults.";
      };
    };
  };

  config = {
    home.file.".local/bin/obsidian-cli-check" = lib.mkIf enableCheck {
      source = pkgs.writeShellScript "obsidian-cli-check" ''
        #!/bin/bash
        VAULT_PATH="$1"
        if [ -f "$VAULT_PATH/.obsidian/app.json" ]; then
          if command -v osascript >/dev/null 2>&1; then
            osascript -e 'tell application "Obsidian" to activate' || true
          fi
          if command -v jq >/dev/null 2>&1; then
            jq '.["commandLineInterface"] = true' "$VAULT_PATH/.obsidian/app.json" > "$VAULT_PATH/.obsidian/app.json.tmp" && mv "$VAULT_PATH/.obsidian/app.json.tmp" "$VAULT_PATH/.obsidian/app.json"
            echo "Obsidian CLI setting verified in $VAULT_PATH."
          else
            echo "Warning: jq not found."
          fi
        else
          echo "Error: Could not find Obsidian config in $VAULT_PATH."
          exit 1
        fi
      '';
    };

    home.sessionPath = lib.mkIf config.obsidian.enable [
      "$HOME/.local/bin"
    ];

    home.activation.obsidianSetup = lib.mkIf enableCheck (
      lib.hm.dag.entryAfter [ "writeBoundary" ] (
        lib.concatStringsSep "\n" (
          map (vault: ''
            $HOME/.local/bin/obsidian-cli-check "${vault}"
          '') vaults
        )
      )
    );
  };
}
