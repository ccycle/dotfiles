{ lib, ... }:

{
  options.custom.storage = {
    volumeRoot = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Root path to the external storage volume (e.g. /Volumes/SSD).";
    };
  };
}
