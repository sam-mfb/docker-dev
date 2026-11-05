STEP_DESC="Rust through rustup, with rust-analyzer"
STEP_RUN_AS=user
STEP_OPTIONAL=1
STEP_REQUIRES="packages build-tools"

toolchain() { is_latest "$RUST_VERSION" && echo stable || echo "$RUST_VERSION"; }

step_version() { rustc --version 2>/dev/null | awk '{print $2}'; }
step_check() {
    if ! has rustup; then
        # A rust from somewhere else is fine unless a version is pinned.
        has rustc && is_latest "$RUST_VERSION"
        return
    fi
    rustup toolchain list | grep -q "^$(toolchain)-" &&
    rustup component list --installed --toolchain "$(toolchain)" | grep -q '^rust-analyzer'
}
step_install() {
    write_env rust <<'EOT'
dd_path_prepend "$HOME/.cargo/bin"
EOT
    export PATH="$HOME/.cargo/bin:$PATH"
    if ! has rustup; then
        run_installer https://sh.rustup.rs -y --no-modify-path --default-toolchain "$(toolchain)"
    else
        rustup toolchain install "$(toolchain)"
        rustup default "$(toolchain)"
    fi
    rustup component add rust-analyzer --toolchain "$(toolchain)"
}
