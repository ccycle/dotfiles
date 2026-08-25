{ pkgs, ... }:
{
  programs.tmux = {
    enable = true;
    # screen-256color avoids color/key issues inside tmux.
    # https://zenn.dev/ymotongpoo/articles/d3b38bee191e3b
    terminal = "screen-256color";
    mouse = true;
    keyMode = "vi";
    plugins = with pkgs.tmuxPlugins; [
      {
        plugin = yank;
        extraConfig = ''
          # コピー時にコピーモードを終了する (ご提示の回答の挙動に合わせる)
          set -g @yank_action 'copy-pipe-and-cancel'
          # マウスドラッグを離した瞬間にクリップボードへ自動コピー
          set -g @yank_with_mouse on
        '';
      }
    ];
    extraConfig = ''
      # Explicitly enable UTF-8 support
      set -as terminal-features ",xterm-256color:UTF-8"

      # --- コピーモードの設定 (Vim風操作) ---
      # v で選択開始
      bind-key -T copy-mode-vi v send-keys -X begin-selection
      # V で行選択
      bind-key -T copy-mode-vi V send-keys -X select-line
      # C-v で矩形選択の切り替え
      bind-key -T copy-mode-vi C-v send-keys -X rectangle-toggle

      # y でコピー (tmux-yankがシステムのクリップボード pbcopy と連携します)

      # Tree Mode (Prefix + w や s) の時に 'x' キーでセッションを終了できるようにする
      bind-key -T copy-mode-vi x confirm-before -p "kill-session #S? (y/n)" "kill-session"
      # ※ tmuxのバージョンによっては以下が推奨されます
      bind-key -T root x if-shell -F "#{==:#{pane_mode},tree-mode}" "confirm-before -p \"kill-session #S? (y/n)\" \"kill-session\"" ""
    '';
  };
}
