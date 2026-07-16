{ lib, ... }:

{
  options.custom.lm-studio = {
    enable = lib.mkEnableOption "LM Studio";
  };
}
