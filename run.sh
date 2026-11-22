#!/bin/bash

# Source user settings if available
if [[ -f ".settings" ]]; then
    source .settings
    echo "Loaded user settings from .settings"
else
    echo "Warning: .settings not found - Azure DevOps MCP will not be available"
    echo "  To enable: cp settings.example .settings && edit .settings"
fi

# Validate ADO_ORG if set
if [[ -n "$ADO_ORG" && "$ADO_ORG" == "your-org-name" ]]; then
    echo "Warning: ADO_ORG not configured - Azure DevOps MCP will not be available"
    unset ADO_ORG
fi

# Configuration
IMAGE_TARGET="sam-dev"
IMAGE_TAG="sam-dev-container"
CONTAINER_NAME="sam-dev-container-active"
DOCKER_USER_HOME="/home/devuser"
HOST_PORTS="3002"
CONTAINER_PORTS="3000"
HOST_PORT_RANGE="3010-3019"
CONTAINER_PORT_RANGE="3010-3019"
HOSTNAME="sam-dev"

# Export for docker-compose
export IMAGE_TAG CONTAINER_NAME HOST_PORTS CONTAINER_PORTS HOST_PORT_RANGE CONTAINER_PORT_RANGE HOSTNAME

OPTIND=1
BUILD_FLAGS="--pull"
FORCE_BUILD=false
OVERRIDE_FILE="docker-compose.override.yml"
NEED_OVERRIDE=false
EXTRA_VOLUMES=""
MOUNT_HOME=""
COMPOSE_FILES=""
USE_TAILSCALE=false
TAILSCALE_COMPOSE_FILE="docker-compose.tailscale.yml"
MOUNT_DOCKER_SOCKET=true
DOCKER_SOCKET_COMPOSE_FILE="docker-compose.docker-socket.yml"

# Pick the right compose file for teardown based on whether the tailscale
# sidecar container exists, so -k/-x clean up correctly regardless of how
# the stack was started.
teardown_compose_files() {
    if docker ps -a --filter "name=^${CONTAINER_NAME}-ts$" --format '{{.Names}}' | grep -q .; then
        echo "-f $TAILSCALE_COMPOSE_FILE"
    else
        echo "-f docker-compose.yml"
    fi
}

# Check for DOCKER_VOLUMES environment variable
if [[ -n "$DOCKER_VOLUMES" ]]; then
    NEED_OVERRIDE=true
    IFS=',' read -ra VOLUMES <<< "$DOCKER_VOLUMES"
    for vol in "${VOLUMES[@]}"; do
        EXTRA_VOLUMES="$EXTRA_VOLUMES      - $vol"$'\n'
    done
    echo "Will mount additional volumes: $DOCKER_VOLUMES"
fi

while getopts ":krxbtDhm:" option; do
    case $option in
        k)
            echo "Stopping and removing containers..."
            docker compose $(teardown_compose_files) down
            exit;;
        r)
            echo "Deleting image..."
            docker rmi ${IMAGE_TAG}
            exit;;
        x)
            echo "Stopping containers and deleting image..."
            docker compose $(teardown_compose_files) down
            docker rmi ${IMAGE_TAG}
            exit;;
        b)
            BUILD_FLAGS="--no-cache --pull"
            FORCE_BUILD=true
            ;;
        t)
            USE_TAILSCALE=true
            ;;
        D)
            MOUNT_DOCKER_SOCKET=false
            echo "Will not mount the host docker socket"
            ;;
        h)
            NEED_OVERRIDE=true
            MOUNT_HOME="      - \${HOME}:/host-home"
            echo "Will mount host home directory to /host-home"
            ;;
        m)
            NEED_OVERRIDE=true
            # Resolve to absolute path
            MOUNT_PATH="$(cd "$OPTARG" 2>/dev/null && pwd || echo "$OPTARG")"
            EXTRA_VOLUMES="$EXTRA_VOLUMES      - ${MOUNT_PATH}:/host-mnt${MOUNT_PATH}"$'\n'
            echo "Will bind mount ${MOUNT_PATH} to /host-mnt${MOUNT_PATH}"
            ;;
    esac
done

export ADO_ORG
export TS_AUTHKEY

# Set up compose files. Default is a single dev container with standard
# docker bridge networking. Pass -t to opt into the tailscale sidecar.
if [[ "$USE_TAILSCALE" == true ]]; then
    if [[ -z "$TS_AUTHKEY" || "$TS_AUTHKEY" == "tskey-auth-..." ]]; then
        echo "Error: -t requires TS_AUTHKEY to be set in .settings."
        echo "  Generate one at https://login.tailscale.com/admin/settings/keys"
        echo "  See settings.example. Omit -t to run without the sidecar."
        exit 1
    fi
    COMPOSE_FILES="-f $TAILSCALE_COMPOSE_FILE"
    echo "Tailscale sidecar enabled."
else
    COMPOSE_FILES="-f docker-compose.yml"
fi
if [[ "$MOUNT_DOCKER_SOCKET" == true ]]; then
    COMPOSE_FILES="$COMPOSE_FILES -f $DOCKER_SOCKET_COMPOSE_FILE"
fi

# Build image if not built already or if -b flag was used
if [[ "$(docker images -q ${IMAGE_TAG} 2> /dev/null)" == "" ]] || [[ "$FORCE_BUILD" == true ]]; then
    if [[ "$FORCE_BUILD" == true ]]; then
        echo "Pruning BuildKit cache..."
        docker builder prune -af --filter=until=0s 2>/dev/null || true
        echo "Building image (no-cache)..."
    else
        echo "Building image..."
    fi
    docker build ${BUILD_FLAGS} --build-arg ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY} --target ${IMAGE_TARGET} -t ${IMAGE_TAG} .
fi

# Generate override file if needed for extra volumes or home mount
if [[ "$NEED_OVERRIDE" == true ]]; then
    cat > "$OVERRIDE_FILE" << EOF
services:
  dev:
    volumes:
${MOUNT_HOME}
${EXTRA_VOLUMES}
EOF
    echo "Generated $OVERRIDE_FILE with additional mounts"
    COMPOSE_FILES="$COMPOSE_FILES -f $OVERRIDE_FILE"
fi

# How copies made in the container reach the Mac clipboard. Programs in the
# container (tmux, Neovim, Claude Code) send each copy as an OSC 52 escape
# sequence. Terminals that support it set the clipboard themselves ("native");
# for the rest, host/osc52wrap sits between docker exec and the terminal and
# runs pbcopy ("wrap"). DOCKER_DEV_CLIPBOARD=auto|wrap|native|off overrides.
clipboard_mode() {
    local mode="${DOCKER_DEV_CLIPBOARD:-auto}"
    case "$mode" in
        wrap|native|off) echo "$mode"; return ;;
        auto) ;;
        *) echo "Warning: DOCKER_DEV_CLIPBOARD=$mode is not auto, wrap, native or off; using auto" >&2 ;;
    esac
    # Wrapping needs macOS's pbcopy and a python3. On a Mac without the Xcode
    # command line tools, /usr/bin/python3 is a stub that offers to install
    # them, so only count it when they are installed.
    local py
    py="$(command -v python3)"
    if [[ "$(uname -s)" != Darwin ]] || ! command -v pbcopy >/dev/null || [[ -z "$py" ]] ||
            { [[ "$py" == /usr/bin/python3 ]] && ! xcode-select -p >/dev/null 2>&1; }; then
        echo off
        return
    fi
    # Terminals known to accept OSC 52 copies out of the box. iTerm2 only does
    # with a setting enabled, which can't be seen from here, so it is wrapped;
    # set DOCKER_DEV_CLIPBOARD=native if yours has it on.
    if [[ -n "$KITTY_WINDOW_ID" ]]; then
        echo native
        return
    fi
    case "$TERM_PROGRAM" in
        ghostty|WezTerm) echo native ;;
        *) echo wrap ;;
    esac
}

attach() {
    local cmd=(docker exec -it --detach-keys='ctrl-z,z' "${CONTAINER_NAME}" bash)
    case "$(clipboard_mode)" in
        wrap)
            echo "Copies in the container go to the Mac clipboard (through host/osc52wrap)."
            python3 "$(dirname "${BASH_SOURCE[0]}")/host/osc52wrap" "${cmd[@]}"
            ;;
        native)
            echo "Copies in the container go to the Mac clipboard (the terminal handles OSC 52)."
            "${cmd[@]}"
            ;;
        *)
            "${cmd[@]}"
            ;;
    esac
}

# Check if containers are already running
if [[ "$(docker compose ${COMPOSE_FILES} ps -q dev 2> /dev/null)" != "" ]]; then
    echo "Dev container is already running, attaching to bash shell..."
    attach
else
    echo "Starting services..."
    docker compose ${COMPOSE_FILES} up -d
    echo "Attaching to dev container..."
    attach
fi
