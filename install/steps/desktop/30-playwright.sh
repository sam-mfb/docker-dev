STEP_DESC="Playwright browsers and the OS libraries they need"
STEP_RUN_AS=user
STEP_OPTIONAL=1
STEP_REQUIRES="node"

# Records which Playwright version's browsers we installed.
MARK="$HOME/.cache/ms-playwright/.docker-dev-version"

step_version() { cat "$MARK" 2>/dev/null; }
step_check() {
    [ -s "$MARK" ] && version_matches "$PLAYWRIGHT_VERSION" "$(step_version)"
}
step_install() {
    local spec="playwright@$PLAYWRIGHT_VERSION"
    is_latest "$PLAYWRIGHT_VERSION" && spec="playwright@latest"
    # --with-deps installs OS libraries through sudo.
    sudo -n true 2>/dev/null || die "installing browser libraries needs passwordless sudo"
    npx -y "$spec" install --with-deps
    mkdir -p "$(dirname "$MARK")"
    npx -y "$spec" --version | awk '{print $2}' > "$MARK"
}
