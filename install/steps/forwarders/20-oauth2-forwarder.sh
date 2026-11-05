STEP_DESC="OAuth2 forwarder client, which opens login pages in the host's browser"
STEP_RUN_AS=user
STEP_OPTIONAL=1
STEP_REQUIRES="node"

step_version() { npm_global_version oauth2-forwarder; }
step_check() {
    npm_global_check oauth2-forwarder "$O2F_VERSION" &&
    same_file "$DD_ROOT/dotfiles/browser_env" "$HOME/.browser_env"
}
step_install() {
    npm_global_install oauth2-forwarder "$O2F_VERSION"
    # `source ~/.browser_env` restores BROWSER after VS Code replaces it.
    place_file "$DD_ROOT/dotfiles/browser_env" "$HOME/.browser_env"
    write_env oauth2-forwarder <<'EOT'
export OAUTH2_FORWARDER_SERVER="${OAUTH2_FORWARDER_SERVER:-host.docker.internal:48272}"
export BROWSER=o2f-browser
EOT
}
