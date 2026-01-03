{ ... }:
{
  # GitHub CLIの基本設定
  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "https";
      prompt = "enabled";
    };

    # GitHub CLIのcredential helperを無効にして、git-credential-managerを使用
    gitCredentialHelper.enable = false;
  };
}
