{
  config,
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

  # username = "" only when modules/user/default-config's placeholder is
  # used - normally unreachable, since scripts/ensure-local.sh always writes
  # a real .local/user before check.sh or darwin-rebuild.sh evaluate this
  # flake. This assertion documents the intent; the empty username still
  # fails the build immediately either way, via nix-darwin's own option type
  # checks (e.g. `users.users."".home` wants an absolute path) elsewhere in
  # the module tree, since not every ${username} consumer is worth guarding
  # individually for a path that should never actually be hit.
  assertions = [
    {
      assertion = username != "";
      message = "username is not set (modules/user/default-config's placeholder was used). Run scripts/ensure-local.sh - or scripts/darwin-rebuild.sh / .agents/skills/verify-change/scripts/check.sh, which call it automatically - to generate .local/user/flake.nix.";
    }
  ];

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
}
