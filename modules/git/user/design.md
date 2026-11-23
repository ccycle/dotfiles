# Git User Signing Design

## Purpose

Sign commits with the SSH key held in the Bitwarden vault, served by rbw-agent's built-in SSH agent, so no passphrase-protected private key file lives on disk.

## Scope of the Redirect

[git-ssh-sign-rbw.sh](git-ssh-sign-rbw.sh) points `SSH_AUTH_SOCK` at rbw-agent only for `ssh-keygen -Y sign`.
`git push` and `ssh` to other hosts keep the default agent, so a locked vault never breaks unrelated SSH.

## Locating the Socket

The socket directory comes from `getconf DARWIN_USER_TEMP_DIR`, not `$TMPDIR`, because SSH sessions and launchd jobs may run without `TMPDIR`.
If rbw-agent itself started without `TMPDIR`, its socket lands under `/tmp`; the wrapper fails instead of guessing that path.

## System ssh-keygen

The wrapper execs `/usr/bin/ssh-keygen` because macOS hosts use the system OpenSSH (see [modules/ssh/home.nix](../../ssh/home.nix)).
