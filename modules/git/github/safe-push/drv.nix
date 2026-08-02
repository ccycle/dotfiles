{ writeShellApplication, tokenFile }:
writeShellApplication {
  name = "git-safe-push";
  text = ''
    # Safety is enforced by construction: the only accepted argument is
    # --dry-run, so force pushes, deletions, refspecs, and alternate
    # remotes cannot be expressed at all.
    # Best-effort audit trail for detection, not the security boundary — see
    # modules/git/design.md. Never write the token itself here.
    log_dir="$HOME/Library/Logs/git-safe-push"
    log_file="$log_dir/audit.log"
    mkdir -p "$log_dir"
    touch "$log_file"
    chmod 600 "$log_file"
    branch=""
    host=""
    log_event() {
      printf '%s\tbranch=%s\thost=%s\toutcome=%s\t%s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "''${branch:-unknown}" "''${host:-unknown}" "$1" "$2" \
        >> "$log_file"
    }

    extra_args=()
    dry_run=false
    case "''${1:-}" in
      "") ;;
      --dry-run)
        extra_args+=(--dry-run)
        dry_run=true
        ;;
      *)
        echo "usage: git-safe-push [--dry-run]" >&2
        echo "Pushes the currently checked-out branch to origin. No other arguments are accepted." >&2
        exit 2
        ;;
    esac

    if ! branch=$(git symbolic-ref --short -q HEAD); then
      echo "git-safe-push: refusing to push from a detached HEAD" >&2
      log_event refused "reason=detached-head"
      exit 1
    fi

    case "$branch" in
      main | master)
        echo "git-safe-push: refusing to push '$branch' directly; push a feature branch and open a PR" >&2
        log_event refused "reason=protected-branch"
        exit 1
        ;;
    esac

    # The token must only ever be sent to github.com. A rewritten or
    # malicious origin URL would otherwise receive the credential, so the
    # host is extracted by parsing rather than glob-matched (a glob like
    # https://*@github.com/* also matches https://evil.com/a@github.com/b).
    url=$(git remote get-url --push origin)
    case "$url" in
      https://*) ;;
      *)
        echo "git-safe-push: origin is not an HTTPS remote: $url" >&2
        log_event refused "reason=non-https-remote"
        exit 1
        ;;
    esac
    host=''${url#https://}
    host=''${host%%/*}
    host=''${host##*@}
    if [ "$host" != "github.com" ]; then
      echo "git-safe-push: origin host is not github.com: $host" >&2
      log_event refused "reason=wrong-host"
      exit 1
    fi

    if [ ! -r "${tokenFile}" ]; then
      echo "git-safe-push: token file not readable: ${tokenFile}" >&2
      echo "Set the fine-grained PAT with: sops modules/git/github/safe-push/secrets.yaml (key: github-agent-push-token), then rebuild." >&2
      log_event refused "reason=token-unreadable"
      exit 1
    fi

    log_event attempt "dry_run=$dry_run"

    # The empty credential.helper clears the configured helpers (osxkeychain,
    # oauth) so no device-flow prompt can trigger; GIT_TERMINAL_PROMPT=0 makes
    # auth failures fail fast instead of hanging. The helper passes only the
    # token file path on the command line, never the token itself.
    status=0
    # shellcheck disable=SC2016 # $(cat ...) is expanded by git at credential-fill time, not here
    GIT_TERMINAL_PROMPT=0 git \
      -c credential.helper= \
      -c 'credential.helper=!f() { echo username=x-access-token; echo "password=$(cat ${tokenFile})"; }; f' \
      push "''${extra_args[@]}" --set-upstream origin "$branch" || status=$?

    if [ "$status" -eq 0 ]; then
      log_event success ""
    else
      log_event failure "exit=$status"
    fi
    exit "$status"
  '';
}
