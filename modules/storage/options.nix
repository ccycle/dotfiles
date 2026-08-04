{ lib, ... }:

{
  options.custom.storage = {
    volumes = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = ''
        Per-service storage root paths, keyed by service name (e.g.
        "forgejo", "llm-server"). Each service builds its data paths under
        its own entry, so services can be split across different volumes.
      '';
    };
  };
}
