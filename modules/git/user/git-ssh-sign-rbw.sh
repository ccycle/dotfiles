# rbw-agent places its socket under std::env::temp_dir(), i.e. $TMPDIR when the agent started: https://github.com/doy/rbw/blob/1.15.0/src/dirs.rs#L92-L106
rbw_agent_temp_dir="$(getconf DARWIN_USER_TEMP_DIR)"

for arg in "$@"; do
  if [ "$arg" = sign ]; then
    sock="${rbw_agent_temp_dir}rbw-$(id -u)/ssh-agent-socket"
    if [ ! -S "$sock" ]; then
      echo "git-ssh-sign-rbw: rbw SSH agent socket not found at $sock (rbw-agent not running, or started without TMPDIR=DARWIN_USER_TEMP_DIR); run 'rbw unlock'" >&2
      exit 1
    fi
    if ! rbw unlocked >/dev/null 2>&1; then
      echo "git-ssh-sign-rbw: rbw is locked; refusing to sign because rbw-agent would block on a pinentry prompt nobody may see; run 'rbw unlock' and retry" >&2
      exit 1
    fi
    export SSH_AUTH_SOCK="$sock"
    break
  fi
done

exec /usr/bin/ssh-keygen "$@"
