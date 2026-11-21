# gpg.ssh.program for git: signs with the key held in the Bitwarden vault via rbw-agent's built-in SSH agent, so no passphrase-protected private key file is needed.
# Only signing is redirected; git push and ssh to other hosts keep using the default agent.
#
# rbw-agent binds its socket under std::env::temp_dir() (= $TMPDIR at agent start), which on macOS is DARWIN_USER_TEMP_DIR.
# getconf is used instead of $TMPDIR because SSH sessions and launchd jobs may lack TMPDIR.
# If the agent was started without TMPDIR (socket under /tmp), this fails loudly instead of guessing.

for arg in "$@"; do
  if [ "$arg" = sign ]; then
    sock="$(getconf DARWIN_USER_TEMP_DIR)rbw-$(id -u)/ssh-agent-socket"
    if [ ! -S "$sock" ]; then
      echo "git-ssh-sign-rbw: rbw SSH agent socket not found at $sock; run 'rbw unlock'" >&2
      exit 1
    fi
    # A locked vault would make rbw-agent spawn pinentry with the last rbw client's environment,
    # which can hang a non-interactive caller (or pop a GUI dialog nobody sees over SSH).
    if ! rbw unlocked >/dev/null 2>&1; then
      echo "git-ssh-sign-rbw: rbw is locked; run 'rbw unlock' and retry" >&2
      exit 1
    fi
    export SSH_AUTH_SOCK="$sock"
    break
  fi
done

# System ssh-keygen (see modules/ssh/home.nix: system SSH is used on macOS).
exec /usr/bin/ssh-keygen "$@"
