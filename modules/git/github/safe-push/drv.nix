{ writeShellApplication, tokenFile }:
writeShellApplication {
  name = "git-safe-push";
  text = ''
    # Safety is enforced by construction: the only accepted argument is
    # --dry-run, so force pushes, deletions, refspecs, and alternate
    # remotes cannot be expressed at all.
    extra_args=()
    case "''${1:-}" in
      "") ;;
      --dry-run) extra_args+=(--dry-run) ;;
      *)
        echo "usage: git-safe-push [--dry-run]" >&2
        echo "Pushes the currently checked-out branch to origin. No other arguments are accepted." >&2
        exit 2
        ;;
    esac

    if ! branch=$(git symbolic-ref --short -q HEAD); then
      echo "git-safe-push: refusing to push from a detached HEAD" >&2
      exit 1
    fi

    case "$branch" in
      main | master)
        echo "git-safe-push: refusing to push '$branch' directly; push a feature branch and open a PR" >&2
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
        exit 1
        ;;
    esac
    host=''${url#https://}
    host=''${host%%/*}
    host=''${host##*@}
    if [ "$host" != "github.com" ]; then
      echo "git-safe-push: origin host is not github.com: $host" >&2
      exit 1
    fi

    if [ ! -r "${tokenFile}" ]; then
      echo "git-safe-push: token file not readable: ${tokenFile}" >&2
      echo "Set the fine-grained PAT with: sops modules/git/github/safe-push/secrets.yaml (key: github-agent-push-token), then rebuild." >&2
      exit 1
    fi

    # The empty credential.helper clears the configured helpers (osxkeychain,
    # oauth) so no device-flow prompt can trigger; GIT_TERMINAL_PROMPT=0 makes
    # auth failures fail fast instead of hanging. The helper passes only the
    # token file path on the command line, never the token itself.
    # shellcheck disable=SC2016 # $(cat ...) is expanded by git at credential-fill time, not here
    GIT_TERMINAL_PROMPT=0 exec git \
      -c credential.helper= \
      -c 'credential.helper=!f() { echo username=x-access-token; echo "password=$(cat ${tokenFile})"; }; f' \
      push "''${extra_args[@]}" --set-upstream origin "$branch"
  '';
}
