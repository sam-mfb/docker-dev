#!/bin/bash

# Configuration
IMAGE_TARGET="ts-dev-align"
IMAGE_TAG="align-ts-dev"
CONTAINER_NAME="align-ts-dev-active"
DOCKER_USER_HOME="/home/devuser"
HOST_PORTS="3002"
CONTAINER_PORTS="3000"
HOSTNAME="ts-docker"
GIT_REPO="https://MFBTech@dev.azure.com/MFBTech/Syzygy%20Web%20App/_git/align-ts"
CLONE_DIR="align-ts"

# Export for docker-compose
export IMAGE_TAG CONTAINER_NAME HOST_PORTS CONTAINER_PORTS HOSTNAME

OPTIND=1
BUILD_FLAGS="--pull"
FORCE_BUILD=false
OVERRIDE_FILE="docker-compose.override.yml"
NEED_OVERRIDE=false
EXTRA_VOLUMES=""
MOUNT_HOME=""

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
            exit;;
        r)
            echo "Deleting image..."
            docker rmi ${IMAGE_TAG}
            exit;;
        x)
            echo "Stopping containers and deleting image..."
            docker compose down
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

# Build image if not built already or if -b flag was used
if [[ "$(docker images -q ${IMAGE_TAG} 2> /dev/null)" == "" ]] || [[ "$FORCE_BUILD" == true ]]; then
    if [[ "$FORCE_BUILD" == true ]]; then
        echo "Building image (no-cache)..."
    else
        echo "Building image..."
    fi
    docker build ${BUILD_FLAGS} --build-arg GIT_REPO=${GIT_REPO} --build-arg ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY} --target ${IMAGE_TARGET} -t ${IMAGE_TAG} .
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
fi

./launch_X.sh

# Check if containers are already running
if [[ "$(docker compose ps -q dev 2> /dev/null)" != "" ]]; then
    echo "Dev container is already running, attaching to bash shell..."
    docker compose exec dev bash
else
    echo "Starting services..."
    docker compose up -d
    echo "Attaching to dev container..."
    docker compose exec dev bash
fi
