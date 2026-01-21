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
HOSTNAME="sam-dev"

# Export for docker-compose
export IMAGE_TAG CONTAINER_NAME HOST_PORTS CONTAINER_PORTS HOSTNAME

OPTIND=1
BUILD_FLAGS="--pull"
FORCE_BUILD=false
OVERRIDE_FILE="docker-compose.override.yml"
NEED_OVERRIDE=false
EXTRA_VOLUMES=""
MOUNT_HOME=""
COMPOSE_FILES=""

# Check for DOCKER_VOLUMES environment variable
if [[ -n "$DOCKER_VOLUMES" ]]; then
    NEED_OVERRIDE=true
    IFS=',' read -ra VOLUMES <<< "$DOCKER_VOLUMES"
    for vol in "${VOLUMES[@]}"; do
        EXTRA_VOLUMES="$EXTRA_VOLUMES      - $vol"$'\n'
    done
    echo "Will mount additional volumes: $DOCKER_VOLUMES"
fi

while getopts ":krxbh" option; do
    case $option in
        k)
            echo "Stopping and removing containers..."
            docker compose down
            # Kill any host MCP gateway process
            pkill -f "docker mcp gateway" 2>/dev/null || true
            exit;;
        r)
            echo "Deleting image..."
            docker rmi ${IMAGE_TAG}
            exit;;
        x)
            echo "Stopping containers and deleting image..."
            docker compose down
            # Kill any host MCP gateway process
            pkill -f "docker mcp gateway" 2>/dev/null || true
            docker rmi ${IMAGE_TAG}
            exit;;
        b)
            BUILD_FLAGS="--no-cache --pull"
            FORCE_BUILD=true
            ;;
        h)
            NEED_OVERRIDE=true
            MOUNT_HOME="      - \${HOME}:/host-home"
            echo "Will mount host home directory to /host-home"
            ;;
    esac
done

# Generate or load MCP gateway auth token
MCP_TOKEN_FILE=".mcp-gateway-token"
if [[ ! -f "$MCP_TOKEN_FILE" ]]; then
    MCP_GATEWAY_AUTH_TOKEN=$(openssl rand -hex 16)
    echo "$MCP_GATEWAY_AUTH_TOKEN" > "$MCP_TOKEN_FILE"
    echo "Generated new MCP gateway auth token"
else
    MCP_GATEWAY_AUTH_TOKEN=$(cat "$MCP_TOKEN_FILE")
fi
export MCP_GATEWAY_AUTH_TOKEN
export ADO_ORG

# Set up compose files
COMPOSE_FILES="-f docker-compose.yml"

# Start host MCP gateway if not already running
if ! curl -s http://localhost:8811/health > /dev/null 2>&1; then
    echo "Starting Docker MCP gateway on host..."
    MCP_GATEWAY_AUTH_TOKEN=$MCP_GATEWAY_AUTH_TOKEN docker mcp gateway run --port 8811 --transport streaming --secrets=docker-desktop > /dev/null 2>&1 &
    MCP_PID=$!
    # Wait for gateway to be ready
    for i in {1..10}; do
        if curl -s http://localhost:8811/health > /dev/null 2>&1; then
            echo "MCP gateway started (PID: $MCP_PID)"
            break
        fi
        sleep 1
    done
else
    echo "MCP gateway already running on port 8811"
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

./launch_X.sh

# Check if containers are already running
if [[ "$(docker compose ${COMPOSE_FILES} ps -q dev 2> /dev/null)" != "" ]]; then
    echo "Dev container is already running, attaching to bash shell..."
    docker compose ${COMPOSE_FILES} exec --detach-keys='ctrl-z,z' dev bash
else
    echo "Starting services..."
    docker compose ${COMPOSE_FILES} up -d
    echo "Attaching to dev container..."
    docker compose ${COMPOSE_FILES} exec --detach-keys='ctrl-z,z' dev bash
fi
