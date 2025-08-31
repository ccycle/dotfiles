{ lib, ... }: {
  # nixpkgsにないパッケージなので、公式のインストール手順をなぞる形で記述している
  # あくまで一時的なもの
  programs.zsh = {
    shellAliases = {
      install-cursor-agent = "curl https://cursor.com/install -fsS | bash";
    };
    initExtra = ''
      export PATH=$HOME/.local/bin:$PATH
    '';
  };
  home.activation.checkCursorAgent = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if ! command -v cursor-agent >/dev/null 2>&1; then
      echo "Warning: cursor-agent is not installed. Please run: curl https://cursor.com/install -fsS | bash"
    else
      echo "(Check) cursor-agent is installed"
    fi
  '';
}
