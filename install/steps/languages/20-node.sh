STEP_DESC="Node.js and npm through nvm (kept as is if a recent node is already installed)"
STEP_RUN_AS=user
STEP_REQUIRES="packages"

# A node that did not come from our nvm (say, the base image's) is accepted when
# it is at least this new, so we don't shadow the version a project chose.
NODE_MIN_MAJOR=20
export NVM_DIR="$HOME/.nvm"

node_spec() { is_latest "$NODE_VERSION" && echo node || echo "$NODE_VERSION"; }
have_nvm()  { [ -s "$NVM_DIR/nvm.sh" ]; }
nvm_load()  { have_nvm && { set +eu; . "$NVM_DIR/nvm.sh"; }; }

step_version() {
    has node || return 0
    local src=system
    [[ "$(command -v node)" == "$NVM_DIR"/* ]] && src=nvm
    echo "node $(node -v), npm $(npm -v 2>/dev/null) ($src)"
}

step_check() {
    if have_nvm; then
        nvm_load || return 1
        version_matches "$NVM_VERSION" "$(nvm --version)" || return 1
        local want; want="$(nvm version "$(node_spec)")"
        [ "$want" != N/A ] && [ "$(nvm version default)" = "$want" ] || return 1
        version_matches "$NPM_VERSION" "$(npm -v)"
    else
        has node || return 1
        local major; major="$(node -v | sed -E 's/^v([0-9]+).*/\1/')"
        [ "$major" -ge "$NODE_MIN_MAJOR" ]
    fi
}

step_install() {
    if ! have_nvm || ! { nvm_load; version_matches "$NVM_VERSION" "$(nvm --version)"; }; then
        local v="$NVM_VERSION"
        is_latest "$v" && v="$(github_latest_tag nvm-sh/nvm)"
        v="${v#v}"
        log "installing nvm $v"
        PROFILE=/dev/null run_installer "https://raw.githubusercontent.com/nvm-sh/nvm/v$v/install.sh"
    fi
    write_env node <<'EOT'
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
EOT
    write_bashrc node <<'EOT'
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
EOT

    # nvm does not tolerate `set -e`, so check each result by hand.
    set +e
    nvm_load || die "nvm did not install"
    nvm install "$(node_spec)" || die "nvm could not install node $(node_spec)"
    nvm alias default "$(node_spec)" || die "nvm alias failed"
    nvm use default >/dev/null || die "nvm use failed"
    set -e

    if ! version_matches "$NPM_VERSION" "$(npm -v)"; then
        local spec="npm@latest"
        is_latest "$NPM_VERSION" || spec="npm@$NPM_VERSION"
        npm install -g --no-fund --no-audit "$spec"
    fi
}
