STEP_DESC=".NET SDK, with trusted HTTPS dev certificates"
STEP_RUN_AS=user
STEP_OPTIONAL=1
STEP_REQUIRES="packages build-tools"

sdk_pin() { is_latest "$DOTNET_VERSION" && echo "$DOTNET_CHANNEL" || echo "$DOTNET_VERSION"; }

step_version() { dotnet --version 2>/dev/null; }
step_check() {
    has dotnet || return 1
    local sdk
    for sdk in $(dotnet --list-sdks 2>/dev/null | awk '{print $1}'); do
        version_matches "$(sdk_pin)" "$sdk" && return 0
    done
    return 1
}
step_install() {
    local args=(--channel "$DOTNET_CHANNEL" --install-dir "$HOME/.dotnet")
    is_latest "$DOTNET_VERSION" || args+=(--version "$DOTNET_VERSION")
    run_installer https://dot.net/v1/dotnet-install.sh "${args[@]}"
    write_env dotnet <<'EOT'
export DOTNET_ROOT="$HOME/.dotnet"
dd_path_prepend "$HOME/.dotnet"
dd_path_append "$HOME/.dotnet/tools"
EOT
    export DOTNET_ROOT="$HOME/.dotnet" PATH="$HOME/.dotnet:$PATH"
    dotnet dev-certs https || warn "could not create HTTPS dev certificates"
}
