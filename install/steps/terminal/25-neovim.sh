STEP_DESC="Neovim, from the official release build"
STEP_RUN_AS=root
STEP_REQUIRES="packages"

# Ubuntu's own neovim package is too old for the config (it needs 0.12+), so
# use the release tarball.
NVIM_DIR=/opt/nvim

nvim_arch() {
    case "$(uname -m)" in
        x86_64|amd64)  echo x86_64 ;;
        aarch64|arm64) echo arm64 ;;
        *) die "unsupported CPU architecture: $(uname -m)" ;;
    esac
}

step_version() { "$NVIM_DIR/bin/nvim" --version 2>/dev/null | head -n1 | awk '{print $2}'; }
step_check() {
    [ -x "$NVIM_DIR/bin/nvim" ] && [ "$(readlink /usr/local/bin/nvim)" = "$NVIM_DIR/bin/nvim" ] &&
    version_matches "$NEOVIM_VERSION" "$(step_version)"
}
step_install() {
    local v="$NEOVIM_VERSION"
    is_latest "$v" && v="$(github_latest_tag neovim/neovim)"
    v="${v#v}"
    local tarball="$DD_RUN_DIR/nvim.tar.gz"
    download "https://github.com/neovim/neovim/releases/download/v$v/nvim-linux-$(nvim_arch).tar.gz" "$tarball"
    rm -rf "$NVIM_DIR.new"
    mkdir -p "$NVIM_DIR.new"
    tar -xzf "$tarball" -C "$NVIM_DIR.new" --strip-components=1
    rm -rf "$NVIM_DIR"
    mv "$NVIM_DIR.new" "$NVIM_DIR"
    ln -sf "$NVIM_DIR/bin/nvim" /usr/local/bin/nvim
}
