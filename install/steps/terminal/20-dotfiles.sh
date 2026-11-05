STEP_DESC="Shell, tmux, and git settings from dotfiles/"
STEP_RUN_AS=user
STEP_REQUIRES="packages"

DOT="$DD_ROOT/dotfiles"
HOOK_BEGIN="# >>> docker-dev >>>"
HOOK='[ -f "$HOME/.docker-dev/bashrc" ] && . "$HOME/.docker-dev/bashrc"'

step_check() {
    same_file "$DOT/bashrc" "$HOME/.docker-dev/bashrc" &&
    same_file "$DOT/tmux.conf" "$HOME/.tmux.conf" &&
    same_file "$DOT/gitconfig" "$HOME/.docker-dev/gitconfig" &&
    same_file "$DD_ROOT/tmux_dev.sh" "$HOME/tmux_dev.sh" &&
    grep -qF "$HOOK_BEGIN" "$HOME/.bashrc" 2>/dev/null &&
    git config --global --get-all include.path 2>/dev/null | grep -qxF "~/.docker-dev/gitconfig"
}
step_version() { echo "dotfiles"; }
step_install() {
    ensure_env_loader
    place_file "$DOT/bashrc" "$HOME/.docker-dev/bashrc"
    place_file "$DOT/tmux.conf" "$HOME/.tmux.conf"
    place_file "$DOT/gitconfig" "$HOME/.docker-dev/gitconfig"
    place_file "$DD_ROOT/tmux_dev.sh" "$HOME/tmux_dev.sh" 0755

    # Hook our bashrc into the user's own, rather than replacing it.
    if ! grep -qF "$HOOK_BEGIN" "$HOME/.bashrc" 2>/dev/null; then
        printf '\n%s\n%s\n# <<< docker-dev <<<\n' "$HOOK_BEGIN" "$HOOK" >> "$HOME/.bashrc"
    fi

    # Include our git settings; settings already in ~/.gitconfig still apply.
    git config --global --get-all include.path 2>/dev/null | grep -qxF "~/.docker-dev/gitconfig" \
        || git config --global --add include.path "~/.docker-dev/gitconfig"
}
