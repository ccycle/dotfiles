{
  lib,
  ...
}:

{
  options.services.mlx-server = {
    enable = lib.mkEnableOption "MLX server (mlx-lm)";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8883;
    };

    modelsDir = lib.mkOption {
      type = lib.types.str;
      default = "/Users/mfuruki/.cache/mlx-models";
      description = "Directory to store downloaded MLX models.";
    };

    defaultModel = lib.mkOption {
      type = lib.types.str;
      default = "mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit";
      description = "Default model to serve.";
    };
  };
}
