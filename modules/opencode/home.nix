{ config, lib, ... }:

let
  catalog = builtins.fromJSON (builtins.readFile ../llm-server/catalog.json);

  opencodeConfig = {
    "$schema" = "https://opencode.ai/config.json";
    provider.${catalog.provider.id} = {
      npm = "@ai-sdk/openai-compatible";
      name = catalog.provider.name;
      options.baseURL = catalog.provider.baseURL;
      models = lib.mapAttrs (_: m: {
        name = m.name;
        limit = {
          context = m.contextLength;
        };
      }) catalog.models;
    };
  };
in
{
  home.file."${config.home.homeDirectory}/.config/opencode/opencode.json".text =
    builtins.toJSON opencodeConfig;
}
