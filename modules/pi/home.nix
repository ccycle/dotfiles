{ config, lib, piPackage, pkgs, ... }:

let
  catalog = builtins.fromJSON (builtins.readFile ../llm-server/catalog.json);

  # Mirror the compat flags pi's built-in llama.cpp provider sets
  # (src/extensions/llama/provider.ts): llama-swap forwards the request body
  # unchanged to llama-server, so the same server constraints apply.
  llamaCppCompat = {
    supportsStore = false;
    supportsDeveloperRole = false;
    supportsReasoningEffort = false;
    supportsUsageInStreaming = true;
    supportsStrictMode = false;
    maxTokensField = "max_tokens";
  };

  # apiKey is a dummy: llama-swap does not authenticate, but pi only lists
  # models whose provider has an API key configured.
  modelsJson = {
    providers.${catalog.provider.id} = {
      name = catalog.provider.name;
      baseUrl = catalog.provider.baseURL;
      api = "openai-completions";
      apiKey = "none";
      compat = llamaCppCompat;
      models = lib.mapAttrsToList
        (id: m: {
          inherit id;
          name = m.name;
          reasoning = m.thinking or false;
          contextWindow = m.contextLength;
          maxTokens = m.contextLength;
          input = [ "text" ];
          cost = { input = 0; output = 0; cacheRead = 0; cacheWrite = 0; };
        } // (lib.optionalAttrs (m.thinking or false) {
          compat.thinkingFormat = "qwen-chat-template";
          compat.chatTemplateKwargs = {
            enable_thinking = { "$var" = "thinking.enabled"; };
            preserve_thinking = true;
          };
        }))
        catalog.models;
    };
  };
in
{
  # See ./design.md for why pi is packaged via the pi.nix flake rather than
  # buildNpmPackage/importNpmLock in modules/nodejs/node-tools. Config files
  # are symlinked directly (see modules/ai-rules/home.nix) rather than going
  # through pi.nix's programs.pi.coding-agent home-manager module.
  #
  # Only bin/pi is added to the profile, not piPackage itself: piPackage's
  # lib/node_modules vendors its own zod, at the same path modules/openclaw
  # uses for its own (different) zod, so merging both into the shared
  # profile via buildEnv fails with a file collision. bin/pi is a
  # makeWrapper script with NODE_PATH baked in as an absolute store path, so
  # it doesn't need lib/ present in the profile to run correctly.
  home.packages = [
    (pkgs.runCommand "pi-coding-agent-bin" { } ''
      mkdir -p $out/bin
      ln -s ${piPackage}/bin/pi $out/bin/pi
    '')
  ];

  # Pi skills directory: symlink to shared user skills
  home.file."${config.home.homeDirectory}/.agents/skills".source =
    config.lib.file.mkOutOfStoreSymlink "${config.custom.dotfiles.dir}/skills/user";

  # Point pi at the self-hosted llama-swap server. See design.md for why
  # models.json is the one declarative pi config file that's safe to own.
  home.file."${config.home.homeDirectory}/.pi/agent/models.json".text =
    builtins.toJSON modelsJson;
}