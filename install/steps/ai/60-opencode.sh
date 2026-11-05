STEP_DESC="opencode"
STEP_RUN_AS=user
STEP_OPTIONAL=1
STEP_REQUIRES="packages"

step_version() { opencode --version 2>/dev/null | head -n1; }
step_check()   { has opencode && version_matches "$OPENCODE_VERSION" "$(step_version)"; }
step_install() {
    local args=(--no-modify-path)
    is_latest "$OPENCODE_VERSION" || args+=(--version "$OPENCODE_VERSION")
    write_env opencode <<'EOT'
dd_path_prepend "$HOME/.opencode/bin"
EOT
    run_installer https://opencode.ai/install "${args[@]}"
}
