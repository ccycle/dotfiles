{ pkgs, ... }:
{
  # GitHub CLIの基本設定
  programs.gh = {
    enable = true;
    # Read-only by default for every caller (humans and any agent): without an explicit GH_TOKEN, gh gets a read-only fine-grained PAT from rbw per invocation, so no broad, non-expiring `gh auth login` token is needed and nothing sits on disk.
    # Writes need an explicit `GH_TOKEN=... gh ...`.
    # A failed rbw lookup aborts rather than silently falling back to the keyring token.
    package = pkgs.symlinkJoin {
      name = "gh-rbw-readonly";
      paths = [ pkgs.gh ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      meta.mainProgram = "gh";
      postBuild = ''
        wrapProgram $out/bin/gh --run '
          if [ -z "''${GH_TOKEN:-}" ]; then
            GH_TOKEN="$(${pkgs.rbw}/bin/rbw get github-pat-readonly)" || exit 1
            export GH_TOKEN
          fi'
      '';
    };
    settings = {
      git_protocol = "https";
      prompt = "enabled";
    };

    # gh module は独自に credential helper を設定するので無効にする
    gitCredentialHelper.enable = false;
  };
}
