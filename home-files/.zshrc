typeset -U path cdpath fpath manpath
for profile in ${(z)NIX_PROFILES}; do
  fpath+=($profile/share/zsh/site-functions $profile/share/zsh/$ZSH_VERSION/functions $profile/share/zsh/vendor-completions)
done

HELPDIR="/nix/store/xxw1kzk7hpcmfqynin603sq6snn2zvjs-zsh-5.9/share/zsh/$ZSH_VERSION/help"

path+="$HOME/.zsh/plugins/powerlevel10k"
fpath+="$HOME/.zsh/plugins/powerlevel10k"
path+="$HOME/.zsh/plugins/powerlevel10k-config"
fpath+="$HOME/.zsh/plugins/powerlevel10k-config"
path+="$HOME/.zsh/plugins/go-task"
fpath+="$HOME/.zsh/plugins/go-task"

# https://stackoverflow.com/questions/67136714/how-to-properly-call-compinit-and-bashcompinit-in-zsh
autoload -Uz compinit bashcompinit && compinit && bashcompinit

source /nix/store/jj37688b88m4bh3ybdsd0ic39s8nqmya-zsh-autosuggestions-0.7.1/share/zsh-autosuggestions/zsh-autosuggestions.zsh
ZSH_AUTOSUGGEST_STRATEGY=(history)


if [[ -f "$HOME/.zsh/plugins/powerlevel10k/share/zsh-powerlevel10k/powerlevel10k.zsh-theme" ]]; then
  source "$HOME/.zsh/plugins/powerlevel10k/share/zsh-powerlevel10k/powerlevel10k.zsh-theme"
fi
if [[ -f "$HOME/.zsh/plugins/powerlevel10k-config/.p10k.zsh" ]]; then
  source "$HOME/.zsh/plugins/powerlevel10k-config/.p10k.zsh"
fi
if [[ -f "$HOME/.zsh/plugins/go-task/completion/zsh/_task" ]]; then
  source "$HOME/.zsh/plugins/go-task/completion/zsh/_task"
fi
# History options should be set in .zshrc and after oh-my-zsh sourcing.
# See https://github.com/nix-community/home-manager/issues/177.
HISTSIZE="100000"
SAVEHIST="100000"

HISTFILE="$HOME/.zsh_history"
mkdir -p "$(dirname "$HISTFILE")"

setopt HIST_FCNTL_LOCK
unsetopt APPEND_HISTORY
setopt HIST_IGNORE_DUPS
unsetopt HIST_IGNORE_ALL_DUPS
unsetopt HIST_SAVE_NO_DUPS
unsetopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_SPACE
unsetopt HIST_EXPIRE_DUPS_FIRST
setopt SHARE_HISTORY
setopt EXTENDED_HISTORY


if [[ $options[zle] = on ]]; then
  eval "$(/nix/store/5ic40gl4i983139gl2l93xnn9hj8avkc-fzf-0.62.0/bin/fzf --zsh)"
fi

# peco
function peco-src () {
  local selected_dir=$(ghq list -p | peco --query "$LBUFFER")
  if [ -n "$selected_dir" ]; then
    BUFFER="cd ${selected_dir}"
    zle accept-line
  fi
  zle clear-screen
}
zle -N peco-src
bindkey '^]' peco-src

bindkey '^[^?' backward-kill-word
bindkey '^[[3;3~' backward-kill-word

# SSH Signing: keys in keychain to agent
# macOS: --apple-load-keychain automatically loads keys from keychain with passphrases.
# This avoids manual ssh-add and leverages macOS native keychain integration.
ssh-add --apple-load-keychain > /dev/null 2>&1

source <(/nix/store/mn0l5pc53icbf25mm4bgpsgjpzad209d-just-1.40.0/bin/just --completions zsh)

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
        BUFFER="cd ${selected_dir}"
        zle accept-line
    fi
    zle clear-screen
}
zle -N fzf-cdr
setopt noflowcontrol
bindkey '^q' fzf-cdr

eval "$(/nix/store/a671fl0060r37cy4s85k1l8zfv5z81la-direnv-2.36.0/bin/direnv hook zsh)"

alias -- ghq-migrator-run-all='ls | xargs -I{} ghq-migrator-run {}
'
alias -- grep-colorize-only='grep --color=auto -z '
alias -- hm-switch='home-manager switch -L --impure'
alias -- nix-daemon-restart='sudo launchctl kickstart -k system/org.nixos.nix-daemon'
alias -- nix-flake-update-input='nix flake lock --update-input '
alias -- nix-format-all='find . -name "*.nix" | xargs nixpkgs-fmt
'
alias -- zsh-restart='exec zsh -l'
source /nix/store/74ik877rgjb7w3bxbpvfdxghkssw2rhp-zsh-syntax-highlighting-0.8.0/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
ZSH_HIGHLIGHT_HIGHLIGHTERS+=()


