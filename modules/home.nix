{ config, lib, ... }:
let
  featureHomes = [
    ./agent-search/home.nix
    ./agents/home.nix
    ./antigravity-cli/home.nix
    ./attic/home.nix
    ./build-tools/home.nix
    ./caddy/home.nix
    ./claude/home.nix
    ./cli-tools/home.nix
    ./cloud-tools/home.nix
    ./cursor/home.nix
    ./obsidian/home.nix
    ./databases/home.nix
    ./difit/home.nix
    ./dotfiles/home.nix
    ./direnv/home.nix
    ./docker/home.nix
    ./dsh/home.nix
    ./emacs/home.nix
    ./fresh/home.nix
    ./forgejo/home.nix
    ./fzf/home.nix
    ./git/home.nix
    ./gitui/home.nix
    ./grafana/home.nix
    ./gmake/home.nix
    ./go-task/home.nix
    ./gpg/home.nix
    ./graphics-tools/home.nix
    ./haskell/home.nix
    ./herdr/home.nix
    ./hunk/home.nix
    ./immich/home.nix
    ./just/home.nix
    ./languages/home.nix
    ./lazygit/home.nix
    ./opencode-web/home.nix
    ./mosh/home.nix
    ./mtplx/home.nix
    ./nh/home.nix
    ./nix/home.nix
    ./nodejs/home.nix
    ./openclaw/home.nix
    ./opencloud/home.nix
    ./opencode/home.nix
    ./php/home.nix
    ./pi/home.nix
    ./pinentry/home.nix
    ./pocket-id/home.nix
    ./python/home.nix
    ./rust/home.nix
    ./serena/home.nix
    ./sops/home.nix
    ./ssh/home.nix
    ./sync-home-files/home.nix
    ./t3code/home.nix
    ./task-check/home.nix
    ./terraform/home.nix
    ./tmux/home.nix
    ./vscode/home.nix
    ./worktrunk/home.nix
    ./yazi/home.nix
    ./zsh/home.nix
  ];

  featureName = featureHome: baseNameOf (dirOf featureHome);
  featureNames = map featureName featureHomes;

  enablePath = optionPath: [ "custom" ] ++ optionPath ++ [ "enable" ];

  enableOption =
    optionPath:
    let
      parentPath = lib.init optionPath;
      label = lib.concatStringsSep "." optionPath;
    in
    {
      options = lib.setAttrByPath (enablePath optionPath) (
        if parentPath == [ ] then
          lib.mkEnableOption "the ${label} home module"
        else
          lib.mkOption {
            type = lib.types.bool;
            default = lib.getAttrFromPath (enablePath parentPath) config;
            defaultText = lib.literalExpression "config.${lib.concatStringsSep "." (enablePath parentPath)}";
            description = "Whether to enable the ${label} home module; follows its parent unless set.";
          }
      );
    };

  isSubmoduleOf = path: child: baseNameOf child == "home.nix" && dirOf (dirOf child) == dirOf path;

  gateModule =
    optionPath: path:
    let
      module = import path;
      moduleFn = if lib.isFunction module then module else _: module;
      gateImport =
        i:
        if !builtins.isPath i then
          i
        else if isSubmoduleOf path i then
          gateModule (optionPath ++ [ (featureName i) ]) i
        else
          gateModule optionPath i;
      gated =
        args:
        let
          evaluated = moduleFn args;
          isShorthand = !(evaluated ? config || evaluated ? options);
        in
        {
          imports = map gateImport (evaluated.imports or [ ]);
          options = if isShorthand then { } else evaluated.options or { };
          config = lib.mkIf (lib.getAttrFromPath (enablePath optionPath) config) (
            if isShorthand then removeAttrs evaluated [ "imports" ] else evaluated.config or { }
          );
        };
    in
    {
      _file = toString path;
      key = toString path;
      imports = [
        (lib.setFunctionArgs gated (lib.functionArgs moduleFn))
      ]
      ++ lib.optional (baseNameOf path == "home.nix") (enableOption optionPath);
    };
in
{
  imports = map (featureHome: gateModule [ (featureName featureHome) ] featureHome) featureHomes;

  options.custom.profile = lib.mkOption {
    type = lib.types.enum [
      "personal"
      "work"
    ];
    description = ''
      "personal" turns on every home module (each can still be turned off).
      "work" turns on none; enable each one with custom.<feature>.enable.
      A sub-module (custom.<feature>.<sub>.enable) follows its parent unless set,
      so a single failing sub-module can be turned off on its own.
    '';
  };

  config = lib.mkIf (config.custom.profile == "personal") {
    custom = lib.genAttrs featureNames (_: {
      enable = lib.mkDefault true;
    });
  };
}
