STEP_DESC="Docker CLI and buildx (talks to a host daemon through a mounted socket)"
STEP_RUN_AS=root
STEP_OPTIONAL=1
STEP_REQUIRES="packages"

step_version() { docker version --format '{{.Client.Version}}' 2>/dev/null || apt_pkg_version docker-ce-cli; }
step_check() {
    has docker && apt_installed docker-buildx-plugin &&
    version_matches "$DOCKER_CLI_VERSION" "$(apt_pkg_version docker-ce-cli)"
}
step_install() {
    local id; id="$(os_id)"
    case "$id" in ubuntu|debian) ;; *) die "Docker's apt repo has no packages for $id" ;; esac
    apt_add_source docker "https://download.docker.com/linux/$id/gpg" \
        "deb [arch=$(deb_arch) signed-by={keyring}] https://download.docker.com/linux/$id $(os_codename) stable"
    apt_install_pinned docker-ce-cli "$DOCKER_CLI_VERSION"
    apt_install docker-buildx-plugin

    # When the host's socket is mounted, it arrives owned by the host's docker
    # group, which means nothing in here. Take it over on shell start.
    write_bashrc docker <<'EOT'
if [ -S /var/run/docker.sock ] && [ ! -w /var/run/docker.sock ] && sudo -n true 2>/dev/null; then
    sudo chown "$USER" /var/run/docker.sock
fi
EOT
}
