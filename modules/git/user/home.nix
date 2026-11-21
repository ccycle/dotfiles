{ pkgs, ... }:
let
  signingKey = ./id_ed25519_signing.pub;
  signProgram = pkgs.writeShellApplication {
    name = "git-ssh-sign-rbw";
    runtimeInputs = [ pkgs.rbw ];
    text = builtins.readFile ./git-ssh-sign-rbw.sh;
  };
in
{
  home.file.".ssh/id_ed25519_signing.pub".source = signingKey;

  # Derived from the signing key so the key material stays in one place.
  # The principal must be prefixed to the key, which is why the .pub itself
  # cannot serve as gpg.ssh.allowedSignersFile.
  xdg.configFile."git/allowed_signers".text =
    ''ccycle713@gmail.com namespaces="git" ${builtins.readFile signingKey}'';

  # Templated (included from modules/git/gitconfig) because the program is a store path.
  # Darwin-only: the wrapper relies on DARWIN_USER_TEMP_DIR and the system ssh-keygen.
  xdg.configFile."git/user/gitconfig".enable = pkgs.stdenv.isDarwin;
  xdg.configFile."git/user/gitconfig".text = ''
    [gpg "ssh"]
        program = ${signProgram}/bin/git-ssh-sign-rbw
  '';
}
