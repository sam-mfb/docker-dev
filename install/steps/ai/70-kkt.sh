STEP_DESC="kashkeshet (kkt), installed but not set up; run \`kkt setup\` to use it"
STEP_RUN_AS=user
STEP_OPTIONAL=1
STEP_REQUIRES="packages"

step_version() { kkt --version 2>/dev/null | awk '{print $NF}'; }
step_check()   { has kkt && version_matches "$KKT_VERSION" "$(step_version)"; }
step_install() {
    local base=https://github.com/sam-mfb/kashkeshet/releases
    local url="$base/latest/download/kashkeshet-installer.sh"
    is_latest "$KKT_VERSION" || url="$base/download/v${KKT_VERSION#v}/kashkeshet-installer.sh"
    # It installs to ~/.cargo/bin.
    write_env cargo-bin <<'EOT'
dd_path_prepend "$HOME/.cargo/bin"
EOT
    KASHKESHET_NO_MODIFY_PATH=1 run_installer "$url"
}
