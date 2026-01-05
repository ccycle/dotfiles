{ pkgs, ... }:

{
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultCommand = "${pkgs.fd}/bin/fd --type f";
    defaultOptions = [ "--height 40%" "--layout=reverse" "--border" ];
    changeDirWidgetCommand = "${pkgs.fd}/bin/fd --type d";
    changeDirWidgetOptions = [ "--preview '${pkgs.tree}/bin/tree -C {} | head -200'" ];
    fileWidgetCommand = "${pkgs.fd}/bin/fd --type f";
    fileWidgetOptions = [ "--preview '${pkgs.bat}/bin/bat --style=numbers --color=always --line-range :500 {}'" ];
  };
  programs.zsh.initContent = ''
    # fzf history
    function fzf-select-history() {
        BUFFER=$(history -n -r 1 | fzf --query "$LBUFFER" --reverse)
        CURSOR=$#BUFFER
        zle reset-prompt
    }
    zle -N fzf-select-history
    bindkey '^r' fzf-select-history

    # fzf cdr
    function fzf-cdr() {
        local selected_dir=$(cdr -l | awk '{ print $2 }' | fzf --reverse)
        if [ -n "$selected_dir" ]; then
            BUFFER="cd ''${selected_dir}"
            zle accept-line
        fi
        zle clear-screen
    }
    zle -N fzf-cdr
    setopt noflowcontrol
    bindkey '^q' fzf-cdr
  '';
}
