STEP_DESC="Claude Code"
STEP_RUN_AS=user
STEP_OPTIONAL=1
STEP_REQUIRES="packages"

step_version() { claude --version 2>/dev/null | awk '{print $1}'; }
step_check() {
    has claude || return 1
    [ "$CLAUDE_VERSION" = stable ] || version_matches "$CLAUDE_VERSION" "$(step_version)"
}
step_install() {
    write_env local-bin <<'EOT'
dd_path_prepend "$HOME/.local/bin"
EOT
    export PATH="$HOME/.local/bin:$PATH"
    run_installer https://claude.ai/install.sh "${CLAUDE_VERSION:-latest}"
}
