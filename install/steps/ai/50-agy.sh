STEP_DESC="Antigravity CLI (agy), which updates itself in the background"
STEP_RUN_AS=user
STEP_OPTIONAL=1
STEP_REQUIRES="packages"

step_version() { first_version "$(agy --version 2>/dev/null)"; }
step_check()   { has agy; }
step_install() {
    is_latest "$AGY_VERSION" || die "its installer can only install the latest release; set AGY_VERSION=latest"
    write_env local-bin <<'EOT'
dd_path_prepend "$HOME/.local/bin"
EOT
    # The installer refuses to replace an existing binary.
    rm -f "$HOME/.local/bin/agy"
    # It also appends PATH lines to .bashrc and .profile, with no option to stop
    # it. env.d already covers PATH, so put those files back afterwards.
    local f
    for f in .bashrc .profile; do
        [ -f "$HOME/$f" ] && cp -p "$HOME/$f" "$DD_RUN_DIR/agy-$f"
    done
    run_installer https://antigravity.google/cli/install.sh
    for f in .bashrc .profile; do
        [ -f "$DD_RUN_DIR/agy-$f" ] && cp -p "$DD_RUN_DIR/agy-$f" "$HOME/$f"
    done
}
