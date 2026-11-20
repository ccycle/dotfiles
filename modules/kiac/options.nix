{ lib, ... }:

{
  options.custom.kiac = {
    enable = lib.mkEnableOption "kiac (Kubernetes on apple/container) and its reboot-resume agent";
  };
}
