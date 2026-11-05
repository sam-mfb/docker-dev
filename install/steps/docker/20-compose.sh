STEP_DESC="Docker Compose plugin"
STEP_RUN_AS=root
STEP_OPTIONAL=1
STEP_REQUIRES="docker-cli"

# Searched before /usr/libexec, where an apt-installed compose plugin would go.
PLUGIN=/usr/local/lib/docker/cli-plugins/docker-compose

step_version() { docker compose version --short 2>/dev/null; }
step_check()   { [ -x "$PLUGIN" ] && version_matches "$DOCKER_COMPOSE_VERSION" "$(step_version)"; }
step_install() {
    local v="$DOCKER_COMPOSE_VERSION"
    is_latest "$v" && v="$(github_latest_tag docker/compose)"
    v="${v#v}"
    mkdir -p "$(dirname "$PLUGIN")"
    download "https://github.com/docker/compose/releases/download/v$v/docker-compose-linux-$(uname -m)" "$PLUGIN.tmp"
    chmod 0755 "$PLUGIN.tmp"
    mv "$PLUGIN.tmp" "$PLUGIN"
}
