STEP_DESC="vim plugins, coc.nvim and its extensions, vim-tmux-navigator"
STEP_RUN_AS=user
STEP_REQUIRES="utils git node"
DOT="$DD_ROOT/dotfiles"
COC_EXTENSIONS=(coc-css coc-eslint coc-html coc-json coc-prettier coc-spell-checker
                coc-tsserver coc-yaml coc-snippets coc-powershell coc-rust-analyzer)
NAVIGATOR="$HOME/.vim/pack/plugins/start/vim-tmux-navigator"

step_check() {
    same_file "$DOT/vimrc-coc" "$HOME/.vimrc" &&
    same_file "$DOT/coc-settings.json" "$HOME/.vim/coc-settings.json" &&
    same_file "$DOT/popup_scroll.vim" "$HOME/.vim/autoload/popup_scroll.vim" &&
    [ -d "$HOME/.vim/plugged/coc.nvim" ] && [ -d "$NAVIGATOR" ] || return 1
    local e
    for e in "${COC_EXTENSIONS[@]}"; do
        [ -d "$HOME/.config/coc/extensions/node_modules/$e" ] || return 1
    done
}
step_version() {
    local n; n="$(ls "$HOME/.vim/plugged" 2>/dev/null | wc -l)"
    echo "$n plugins, ${#COC_EXTENSIONS[@]} coc extensions"
}
step_install() {
    if [ -d "$NAVIGATOR/.git" ]; then
        git -C "$NAVIGATOR" pull --ff-only -q
    else
        git clone -q https://github.com/christoomey/vim-tmux-navigator.git "$NAVIGATOR"
    fi

    # The install vimrc bootstraps vim-plug and lists the plugins; the full
    # vimrc needs the plugins already present.
    place_file "$DOT/vimrc-coc-install" "$HOME/.vimrc"
    vim +'PlugInstall --sync' +qa </dev/null >/dev/null 2>&1 || true
    [ -d "$HOME/.vim/plugged/coc.nvim" ] || die "vim-plug did not install coc.nvim"

    place_file "$DOT/vimrc-coc" "$HOME/.vimrc"
    vim +"CocInstall -sync ${COC_EXTENSIONS[*]}" +qa </dev/null >/dev/null 2>&1 || true
    vim +'CocUpdateSync' +qa </dev/null >/dev/null 2>&1 || true

    place_file "$DOT/coc-settings.json" "$HOME/.vim/coc-settings.json"
    place_file "$DOT/popup_scroll.vim" "$HOME/.vim/autoload/popup_scroll.vim"
}
