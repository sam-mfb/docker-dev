DOTFILES_DIR="~/.dotfiles"

zstyle ':completion:*:*:git:*' script ~/.zsh/git-completion.bash
fpath=(~/.zsh $fpath)

autoload -Uz compinit && compinit

# commands relative to root of current git repository
alias cdg='cd "$(git rev-parse --show-cdup)"'
alias lsg='ls "$(git rev-parse --show-cdup)"'

# commands to load specific pre-configured versions of vim
alias vimos='vim -u "$DOTFILES_DIR/vimrc-omni"'
alias vimcoc='vim -u "$DOTFILES_DIR/vimrc-coc"'

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# enable vi mode
bindkey -v

# show hostname cwd in shell on non-mac systems
if [[ `uname` != "Darwin" ]]; then
  export PS1="%B%F{240}%m %1~%f%b %# "
fi
