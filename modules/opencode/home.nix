{ config, lib, ... }:

let
  catalogs = [
    (builtins.fromJSON (builtins.readFile ../llm-server/catalog.json))
    (builtins.fromJSON (builtins.readFile ../mtplx/catalog.json))
    (builtins.fromJSON (builtins.readFile ../mlx-server/catalog.json))
  ];

  providerFromCatalog = catalog: {
    name = catalog.provider.id;
    value = {
      npm = "@ai-sdk/openai-compatible";
      name = catalog.provider.name;
      options.baseURL = catalog.provider.baseURL;
      models = lib.mapAttrs (
        _: m:
        {
          name = m.name;
          limit = {
            context = m.contextLength;
            output = m.contextLength;
          };
        }
        // (lib.optionalAttrs (m ? reasoningEffort) {
          options.reasoningEffort = m.reasoningEffort;
        })
      ) catalog.models;
    };
  };

  opencodeConfig = {
    "$schema" = "https://opencode.ai/config.json";
    permission = {
      "*" = "allow";
    };
    plugin = [
      "@dietrichgebert/ponytail"
      "@zhafron/opencode-memory-md"
    ];
    provider = (builtins.listToAttrs (map providerFromCatalog catalogs)) // {
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
    config.lib.file.mkOutOfStoreSymlink "${config.custom.dotfiles.dir}/.agents/agents/measure-reviewer.md";

  home.file."${config.home.homeDirectory}/.config/opencode/memory/MEMORY.md".source =
    config.lib.file.mkOutOfStoreSymlink "${config.custom.dotfiles.dir}/modules/opencode/memory/MEMORY.md";

  home.file."${config.home.homeDirectory}/.config/opencode/memory/USER.md".source =
    config.lib.file.mkOutOfStoreSymlink "${config.custom.dotfiles.dir}/modules/opencode/memory/USER.md";

  home.file."${config.home.homeDirectory}/.config/opencode/memory/IDENTITY.md".source =
    config.lib.file.mkOutOfStoreSymlink "${config.custom.dotfiles.dir}/modules/opencode/memory/IDENTITY.md";
}
