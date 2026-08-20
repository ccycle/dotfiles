{ lib, ... }:
{
  options.services.mtplx = {
    enable = lib.mkEnableOption "MTPLX (native MTP speculative-decoding server for MLX models)";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8881;
    };

    installDir = lib.mkOption {
      type = lib.types.str;
      default = "$HOME/Library/Application Support/MTPLX";
      description = "Where the DMG's PythonRuntime + wheel are extracted. Uses a literal $HOME, expanded by the launchd script's shell, not by Nix.";
    };

    dmgVersion = lib.mkOption {
      type = lib.types.str;
      default = "2.8.3";
    };

    dmgSha256 = lib.mkOption {
      type = lib.types.str;
      default = "2807c17e6fc8ec4bab7b4d9249bad173a3350b94284d6e7abbb69d9ea1025e33";
      description = "sha256 of MTPLX-<dmgVersion>.dmg, from the release's published SHA256SUMS.";
    };
  };
}
