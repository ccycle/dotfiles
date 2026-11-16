{
  config,
  lib,
  piPackage,
  pkgs,
  ...
}:

let
  catalog = builtins.fromJSON (builtins.readFile ../llm-server/catalog.json);

  # Ollama's OpenAI-compatible endpoint takes `reasoning_effort` (including
  # "none" to turn thinking off), which is pi's default thinkingFormat, so
  # thinking needs no per-model chat-template kwargs.
  ollamaCompat = {
    supportsStore = false;
    supportsDeveloperRole = false;
    supportsReasoningEffort = true;
    supportsUsageInStreaming = true;
    supportsStrictMode = false;
    maxTokensField = "max_tokens";
  };

  # apiKey is a dummy: Ollama does not authenticate, but pi only lists
  # models whose provider has an API key configured.
  modelsJson = {
    providers.${catalog.provider.id} = {
      name = catalog.provider.name;
      baseUrl = catalog.provider.baseURL;
      api = "openai-completions";
      apiKey = "none";
      compat = ollamaCompat;
      models = lib.mapAttrsToList (id: m: {
        inherit id;
        name = m.name;
        reasoning = m.thinking or false;
        contextWindow = m.contextLength;
        maxTokens = m.contextLength;
        input = [ "text" ];
        cost = {
          input = 0;
          output = 0;
          cacheRead = 0;
          cacheWrite = 0;
        };
      }) catalog.models;
    };
  };
in
{
  # See ./design.md for why pi is packaged via the pi.nix flake rather than
  # buildNpmPackage/importNpmLock in modules/nodejs/node-tools. Config files
  # are symlinked directly (see modules/agents/rules/home.nix) rather than going
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

  # Point pi at the self-hosted Ollama server. See design.md for why
  # models.json is the one declarative pi config file that's safe to own.
  home.file."${config.home.homeDirectory}/.pi/agent/models.json".text = builtins.toJSON modelsJson;

  # Live-edit settings.json from the dotfiles checkout. pi rewrites this file
  # at runtime (/model, pi config, pi install), so an out-of-store symlink lets
  # the changes land in the tracked file instead of a Nix-owned copy — same
  # pattern as ~/.claude/settings.json (see modules/claude/home.nix). Commit
  # the resulting diff in modules/pi/settings.json to update the baseline.
  home.file."${config.home.homeDirectory}/.pi/agent/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${config.custom.dotfiles.dir}/modules/pi/settings.json";
}
