#!/bin/bash

# Experimental container run script
# Launches an isolated container for running Claude Code in YOLO mode.
# Uses Docker internal network + proxy sidecar for host isolation.
# The exp container has no direct route to the host or internet -- all
# traffic goes through the proxy sidecar, which restricts host access
# to port 48272 (OAuth2 forwarder) + DNS only.

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
IMAGE_TAG="sam-exp-container"
PROXY_IMAGE_TARGET="exp-proxy"
PROXY_IMAGE_TAG="exp-proxy-container"
CONTAINER_NAME="sam-exp-container-active"
PROXY_CONTAINER_NAME="exp-proxy-container-active"
HOSTNAME="sam-exp"

# Export for docker-compose
export IMAGE_TAG CONTAINER_NAME HOSTNAME
export PROXY_IMAGE_TAG PROXY_CONTAINER_NAME
export ADO_ORG

OPTIND=1
BUILD_FLAGS="--pull"
FORCE_BUILD=false
COMPOSE_FILES="-f docker-compose.exp.yml"

while getopts ":krxb" option; do
    case $option in
        k)
            echo "Stopping and removing experimental containers..."
            docker compose $COMPOSE_FILES down
            exit;;
        r)
            echo "Deleting images..."
            docker rmi ${IMAGE_TAG} 2>/dev/null
            docker rmi ${PROXY_IMAGE_TAG} 2>/dev/null
            exit;;
        x)
            echo "Stopping experimental containers and deleting images..."
            docker compose $COMPOSE_FILES down
            docker rmi ${IMAGE_TAG} 2>/dev/null
            docker rmi ${PROXY_IMAGE_TAG} 2>/dev/null
            exit;;
        b)
            BUILD_FLAGS="--no-cache --pull"
            FORCE_BUILD=true
            ;;
    esac
done

# Build main image if not built already or if -b flag was used
if [[ "$(docker images -q ${IMAGE_TAG} 2> /dev/null)" == "" ]] || [[ "$FORCE_BUILD" == true ]]; then
    if [[ "$FORCE_BUILD" == true ]]; then
        echo "Pruning BuildKit cache..."
        docker builder prune -af --filter=until=0s 2>/dev/null || true
        echo "Building main image (no-cache)..."
    else
        echo "Building main image..."
    fi
    docker build ${BUILD_FLAGS} --target ${IMAGE_TARGET} -t ${IMAGE_TAG} .
fi

# Build proxy sidecar image if not built already or if -b flag was used
if [[ "$(docker images -q ${PROXY_IMAGE_TAG} 2> /dev/null)" == "" ]] || [[ "$FORCE_BUILD" == true ]]; then
    echo "Building proxy sidecar image..."
    docker build ${BUILD_FLAGS} --target ${PROXY_IMAGE_TARGET} -t ${PROXY_IMAGE_TAG} .
fi

# Check if container is already running
if [[ "$(docker compose ${COMPOSE_FILES} ps -q exp 2> /dev/null)" != "" ]]; then
    echo "Experimental container is already running, attaching to bash shell..."
    docker exec -it --detach-keys='ctrl-z,z' ${CONTAINER_NAME} bash
else
    echo "Starting proxy sidecar and experimental container..."
    docker compose ${COMPOSE_FILES} up -d
    echo "Attaching to experimental container..."
    docker exec -it --detach-keys='ctrl-z,z' ${CONTAINER_NAME} bash
fi
