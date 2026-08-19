{ config, lib, ... }:

let
  catalog = builtins.fromJSON (builtins.readFile ../llm-server/catalog.json);

  opencodeConfig = {
    "$schema" = "https://opencode.ai/config.json";
    permission = {
      "*" = "allow";
    };
    provider = {
      ${catalog.provider.id} = {
        npm = "@ai-sdk/openai-compatible";
        name = catalog.provider.name;
        options.baseURL = catalog.provider.baseURL;
        models = lib.mapAttrs
          (_: m: {
            name = m.name;
            limit = {
              context = m.contextLength;
              output = m.contextLength;
            };
          } // (lib.optionalAttrs (m ? reasoningEffort) {
            options.reasoningEffort = m.reasoningEffort;
          }))
          catalog.models;
      };
      kimi = {
        npm = "@ai-sdk/openai-compatible";
        name = "kimi";
        options.baseURL = "https://api.moonshot.cn/v1";
        models = {
          "kimi-k2.5" = {
            name = "kimi k2.5";
          };
        };
      };
    };
  };
in
{
  home.file."${config.home.homeDirectory}/.config/opencode/opencode.json".text =
    builtins.toJSON opencodeConfig;

  home.file."${config.home.homeDirectory}/.config/opencode/agents/measure-reviewer.md".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.custom.dotfiles.dir}/.agents/agents/measure-reviewer.md";
}
