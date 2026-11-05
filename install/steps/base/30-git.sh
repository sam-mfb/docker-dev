STEP_DESC="git (latest from the git-core PPA on Ubuntu)"
STEP_RUN_AS=root
STEP_REQUIRES="packages"

step_version() { git --version 2>/dev/null | awk '{print $3}'; }
step_check()   { has git && version_matches "$GIT_VERSION" "$(step_version)"; }
step_install() {
    require_apt
    if [ "$(os_id)" = ubuntu ]; then
        if ! grep -rqs git-core/ppa /etc/apt/sources.list.d/; then
            apt_install software-properties-common
            add-apt-repository -y ppa:git-core/ppa
            rm -f "$DD_RUN_DIR/apt-updated"
        fi
    fi
    apt_install_pinned git "$GIT_VERSION"
}
