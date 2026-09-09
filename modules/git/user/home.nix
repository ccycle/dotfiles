{ ... }:
let
  signingKey = ./id_ed25519_signing.pub;
in
{
  home.file.".ssh/id_ed25519_signing.pub".source = signingKey;

  # Derived from the signing key so the key material stays in one place.
  # The principal must be prefixed to the key, which is why the .pub itself
  # cannot serve as gpg.ssh.allowedSignersFile.
  xdg.configFile."git/allowed_signers".text =
    ''ccycle713@gmail.com namespaces="git" ${builtins.readFile signingKey}'';
}
