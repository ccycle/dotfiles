{
  config,
  username,
  inputs,
  ...
}:

{
  imports = [
    inputs.sops-nix.darwinModules.sops
  ];

  sops.age.keyFile = "${config.users.users.${username}.home}/.config/sops/age/keys.txt";
  # Since we are not using SSH keys for sops, we can disable this to avoid warnings/errors
  sops.age.sshKeyPaths = [ ];
  sops.gnupg.sshKeyPaths = [ ];
}
