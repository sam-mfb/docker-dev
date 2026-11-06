STEP_DESC="Meta's Muse Code (muse), which updates itself in the background"
STEP_RUN_AS=user
STEP_OPTIONAL=1
STEP_REQUIRES="packages"

# The installer puts a launcher script at ~/.local/bin/muse. The launcher
# downloads the real binary next to itself and records its version in
# .muse-version. Read that file rather than run muse, which may start an
# update or a sign-in.
MUSE_DIR="$HOME/.local/bin"

step_version() { head -n1 "$MUSE_DIR/.muse-version" 2>/dev/null; }
step_check()   { has muse && [ -n "$(step_version)" ]; }
step_install() {
    is_latest "$MUSE_VERSION" || die "its installer can only install the latest release; set MUSE_VERSION=latest"
    write_env local-bin <<'EOT'
dd_path_prepend "$HOME/.local/bin"
EOT
    export PATH="$MUSE_DIR:$PATH"
    # env.d covers PATH, so stop the installer editing .bashrc and .profile.
    # Never start the browser sign-in here; it happens on first run of muse.
    MUSE_INSTALL_DIR="$MUSE_DIR" MUSE_NO_MODIFY_PATH=1 MUSE_LOGIN=0 \
        run_installer https://dev.meta.ai/install.sh
}
