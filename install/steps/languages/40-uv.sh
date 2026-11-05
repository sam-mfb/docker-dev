STEP_DESC="uv, the Python package and project manager"
STEP_RUN_AS=user
STEP_OPTIONAL=1
STEP_REQUIRES="packages"

step_version() { uv --version 2>/dev/null | awk '{print $2}'; }
step_check()   { has uv && version_matches "$UV_VERSION" "$(step_version)"; }
step_install() {
    local url=https://astral.sh/uv/install.sh
    is_latest "$UV_VERSION" || url="https://astral.sh/uv/$UV_VERSION/install.sh"
    write_env local-bin <<'EOT'
dd_path_prepend "$HOME/.local/bin"
EOT
    export PATH="$HOME/.local/bin:$PATH"
    UV_NO_MODIFY_PATH=1 run_installer "$url"
}
