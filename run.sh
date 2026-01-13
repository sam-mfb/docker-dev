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

# flags to easily delete image and container
OPTIND=1
MOUNT_HOME=""
BUILD_FLAGS="--pull"
FORCE_BUILD=false
EXTRA_VOLUMES=""

# Check for DOCKER_VOLUMES environment variable
if [[ -n "$DOCKER_VOLUMES" ]]; then
    IFS=',' read -ra VOLUMES <<< "$DOCKER_VOLUMES"
    for vol in "${VOLUMES[@]}"; do
        EXTRA_VOLUMES="$EXTRA_VOLUMES -v $vol"
    done
    echo "Will mount additional volumes: $DOCKER_VOLUMES"
fi

while getopts ":krxbh" option; do
    case $option in
        k)
            echo "Deleting container..."
            docker container rm ${CONTAINER_NAME}
            exit;;
        r)
            echo "Deleting image..."
            docker rmi ${IMAGE_TAG}
            exit;;
        x)
            echo "Deleting image and container..."
            docker container rm ${CONTAINER_NAME}
            docker rmi ${IMAGE_TAG}
            exit;;
        b)
            BUILD_FLAGS="--no-cache --pull"
            FORCE_BUILD=true
            ;;
        h)
            MOUNT_HOME="--mount type=bind,src=${HOME},target=/host-home"
            echo "Will mount host home directory to /host-home"
            ;;
    esac
done

# build image if not built already or if -b flag was used
if [[ "$(docker images -q ${IMAGE_TAG} 2> /dev/null)" == "" ]] || [[ "$FORCE_BUILD" == true ]]; then
    if [[ "$FORCE_BUILD" == true ]]; then
        echo "Building image (no-cache)..."
    else
        echo "Building image..."
    fi
    docker build ${BUILD_FLAGS} --build-arg GIT_REPO=${GIT_REPO} --build-arg ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY} --target ${IMAGE_TARGET} -t ${IMAGE_TAG} .
fi

./launch_X.sh

# run container if not created, otherwise attach to existing
if [[ "$(docker container ls -qa --filter name=${CONTAINER_NAME} 2> /dev/null)" == "" ]]; then
    echo "Creating and running container..."
    # Options:
    #  - bind ssh to share keys and config
    #  - bind docker socket to allow docker within docker simulation
    #  - increase /dev/shm size as chrome needs a lot
    #  - set detach key to ctrl z,z to free up ctrl,p (the default)
    #  - set DISPLAY env so we can use XServer over the network
    #  - use a custome seccomp profile that enables chrome sandbox
    docker run -p ${HOST_PORTS}:${CONTAINER_PORTS} --mount type=bind,src=/var/run/docker.sock,target=/var/run/docker.sock ${MOUNT_HOME} ${EXTRA_VOLUMES} --shm-size=2gb --detach-keys='ctrl-z,z' --name ${CONTAINER_NAME} -e DISPLAY=host.docker.internal:0 --security-opt seccomp=custom-seccomp.json -h ${HOSTNAME} -it ${IMAGE_TAG}
else
    # Check if container is already running
    if [[ "$(docker container ls -q --filter name=${CONTAINER_NAME} 2> /dev/null)" != "" ]]; then
        echo "Container is already running, attaching to bash shell..."
        docker exec --detach-keys='ctrl-z,z' -it ${CONTAINER_NAME} bash
    else
        echo "Starting and attaching to existing container..."
        docker start --detach-keys='ctrl-z,z' -i ${CONTAINER_NAME}
    fi
fi
