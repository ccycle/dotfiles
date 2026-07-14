{ ... }:
{
  # GitHub CLIの基本設定
  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "https";
      prompt = "enabled";
    };

    # gh module は独自に credential helper を設定するので無効にする
    gitCredentialHelper.enable = false;
  };
}
