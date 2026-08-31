{
  config,
  lib,
  pkgs,
  inputs,
  username,
  homeDirectory,
  ...
}:

{
  imports = [
    ./bootstrap/modules/darwin.nix
    ./modules/darwin.nix
    inputs.storage-config.darwinModules.default
    inputs.dotfiles-config.darwinModules.default
  ];

  config = lib.mkMerge [
    {
      # username = "" only when modules/user/default-config's placeholder is
      # used - normally unreachable, since scripts/ensure-local.sh always writes
      # a real .local/user before check.sh or darwin-rebuild.sh evaluate this
      # flake. Guarding users.users and system.primaryUser behind mkIf ensures
      # the assertion fires first with a clean error message instead of the
      # confusing "users.users.\"\".home is not of type null or absolute path"
      # type error.
      assertions = [
        {
          assertion = username != "";
          message = "username is not set (modules/user/default-config's placeholder was used). Run scripts/ensure-local.sh - or scripts/darwin-rebuild.sh / .agents/skills/verify-change/scripts/check.sh, which call it automatically - to generate .local/user/flake.nix.";
        }
      ];
    }
    (lib.mkIf (username != "") {
      # Required for launchd.user.agents
      system.primaryUser = username;

      users.users."${username}" = {
        home = homeDirectory;
        shell = pkgs.zsh;
      };

      # Home Manager configuration
      home-manager.extraSpecialArgs = inputs.self.extraSpecialArgs.${pkgs.stdenv.hostPlatform.system} // {
        dotfilesDir = config.custom.dotfiles.dir;
      };
      home-manager.users."${username}" = {
        imports = [
          ./home.nix
          inputs.sops-nix.homeManagerModules.sops
          inputs.obsidian-vault-config.homeManagerModules.default
        ];
      };
    })
  ];
}
