# prevent tmux from causing a resourcing of /etc/zprofile
# https://superuser.com/questions/544989/does-tmux-sort-the-path-variable
if [ -n "$TMUX" ] && [ -f /etc/zprofile ]; then
    PATH=""
    source /etc/zprofile
fi

eval "$(/opt/homebrew/bin/brew shellenv)"
