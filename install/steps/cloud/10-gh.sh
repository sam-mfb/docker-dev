STEP_DESC="GitHub CLI"
STEP_RUN_AS=root
STEP_OPTIONAL=1
STEP_REQUIRES="packages"

step_version() { gh --version 2>/dev/null | head -n1 | awk '{print $3}'; }
step_check()   { has gh && version_matches "$GH_VERSION" "$(step_version)"; }
step_install() {
    apt_add_source githubcli https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        "deb [arch=$(deb_arch) signed-by={keyring}] https://cli.github.com/packages stable main"
    apt_install_pinned gh "$GH_VERSION"
}
