STEP_DESC="Neovim config, plugins, language servers and treesitter parsers"
STEP_RUN_AS=user
# build-tools: a C compiler for the treesitter parsers.
STEP_REQUIRES="neovim utils git node build-tools"

DOT="$DD_ROOT/dotfiles"
CONF="$HOME/.config/nvim"
DATA="$HOME/.local/share/nvim"
CSPELL="$HOME/.config/cspell"
BLINK_LIB="$DATA/lazy/blink.cmp/target/release/libblink_cmp_fuzzy.so"
# Seconds any one headless Neovim run may take. Some plugin commands wait
# forever when the network fails (MasonToolsInstallSync, for one), which would
# otherwise hang an image build.
NVIM_TIMEOUT="${NVIM_TIMEOUT:-1800}"

# nvim_headless ARGS... -- headless Neovim with the full config, time-limited.
nvim_headless() { timeout "$NVIM_TIMEOUT" nvim --headless "$@" </dev/null; }

# nvim_lua CODE -- run Lua in headless Neovim with the full config loaded.
# Fails if the code raises an error.
nvim_lua() {
    nvim_headless \
        -c "lua local ok, err = pcall(function() $1 end) if not ok then io.stderr:write(tostring(err), '\n') vim.cmd('cquit') end" \
        -c 'qall!'
}

# tools_list NAME -- one entry per line from the repo's lua/config/tools.lua.
tools_list() {
    nvim --headless --clean --cmd "set rtp^=$DOT/nvim" \
        -c "lua io.stdout:write(table.concat(require('config.tools').$1, '\n'), '\n')" \
        -c 'qall!' </dev/null
}

config_files() { (cd "$DOT/nvim" && find . -type f | sed 's|^\./||' | sort); }

# Every plugin in the lock file is present at its locked commit.
plugins_ok() {
    local name commit
    while IFS=$'\t' read -r name commit; do
        [ "$(git -C "$DATA/lazy/$name" rev-parse HEAD 2>/dev/null)" = "$commit" ] || return 1
    done < <(jq -r 'to_entries[] | "\(.key)\t\(.value.commit)"' "$DOT/nvim/lazy-lock.json")
}
mason_ok() {
    local p
    for p in $(tools_list mason); do [ -d "$DATA/mason/packages/$p" ] || return 1; done
}
parsers_ok() {
    local p
    for p in $(tools_list parsers); do [ -f "$DATA/site/parser/$p.so" ] || return 1; done
}

step_check() {
    local f
    for f in $(config_files); do same_file "$DOT/nvim/$f" "$CONF/$f" || return 1; done
    same_file "$DOT/cspell/cspell.json" "$CSPELL/cspell.json" &&
    same_file "$DOT/cspell/docker-dev-words.txt" "$CSPELL/docker-dev-words.txt" &&
    [ -f "$CSPELL/my-words.txt" ] && [ -f "$BLINK_LIB" ] &&
    plugins_ok && mason_ok && parsers_ok
}
step_version() {
    local n m p
    n="$(jq 'length' "$CONF/lazy-lock.json" 2>/dev/null || echo 0)"
    m="$(ls "$DATA/mason/packages" 2>/dev/null | wc -l)"
    p="$(ls "$DATA/site/parser" 2>/dev/null | wc -l)"
    echo "$n plugins, $m tools, $p parsers"
}
step_install() {
    # Config. Files we placed before that are no longer in the repo are
    # removed, so a renamed plugin file doesn't load twice.
    local f placed
    placed="$(dd_dir)/placed"
    for f in $(config_files); do place_file "$DOT/nvim/$f" "$CONF/$f"; done
    if [ -d "$CONF" ]; then
        while IFS= read -r f; do
            [ -e "$DOT/nvim/${f#"$CONF"/}" ] && continue
            grep -qxF "$f" "$placed" 2>/dev/null && rm -f "$f"
        done < <(find "$CONF" -type f)
    fi

    place_file "$DOT/cspell/cspell.json" "$CSPELL/cspell.json"
    place_file "$DOT/cspell/docker-dev-words.txt" "$CSPELL/docker-dev-words.txt"
    touch "$CSPELL/my-words.txt"   # cspell fails on a missing dictionary file

    # Plugins, at the commits in lazy-lock.json. Starting Neovim installs any
    # that are missing; restore moves the rest to their locked commits. When
    # lazy.nvim installs a plugin it rewrites the lock file from what is on
    # disk, so put the repo's copy back and restore a second time if needed.
    # The git progress output is long, so keep it out of the log unless needed.
    local lazy_log="$DD_RUN_DIR/lazy-restore.log" attempt
    for attempt in 1 2; do
        place_file "$DOT/nvim/lazy-lock.json" "$CONF/lazy-lock.json"
        nvim_headless '+Lazy! restore' +qall >"$lazy_log" 2>&1 || warn "Lazy restore did not finish cleanly"
        if plugins_ok; then break; fi
    done
    if ! plugins_ok; then
        tail -n 40 "$lazy_log" >&2
        die "plugins do not match lazy-lock.json; see :Lazy"
    fi

    # blink.cmp's prebuilt fuzzy matcher for the locked release. Without it
    # completion still works, with a slower Lua matcher and a warning.
    if [ ! -f "$BLINK_LIB" ]; then
        nvim_lua "local done, err = false, nil
            require('blink.cmp.fuzzy.download').ensure_downloaded(function(e) err = e; done = true end)
            vim.wait(300000, function() return done end, 200)
            if not done or err then error('blink.cmp download failed: ' .. tostring(err)) end" \
            || warn "blink.cmp fuzzy matcher not downloaded; completion falls back to Lua"
    fi

    # Language servers and tools (the list is in lua/config/tools.lua).
    nvim_headless '+MasonToolsInstallSync' +qall || warn "Mason install did not finish cleanly"
    mason_ok || die "Mason did not install every tool; see :Mason"

    # Treesitter parsers, compiled with Mason's tree-sitter-cli. update()
    # rebuilds installed parsers when the lock file moved nvim-treesitter.
    nvim_lua "local ts = require('nvim-treesitter')
        if not ts.install(require('config.tools').parsers):wait(1800000) then error('parser install failed') end
        if not ts.update():wait(1800000) then error('parser update failed') end"
    parsers_ok || die "treesitter parsers missing; see :checkhealth nvim-treesitter"
}
