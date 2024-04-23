#!/bin/bash

IMAGE_TARGET="ts-dev-align"
IMAGE_TAG="align-ts-dev"
CONTAINER_NAME="align-ts-dev-active"
DOCKER_USER_HOME="/home/devuser"
HOST_PORTS="3002"
CONTAINER_PORTS="3000"
HOSTNAME="ts-docker"
GIT_REPO="https://MFBTech@dev.azure.com/MFBTech/Syzygy%20Web%20App/_git/align-ts"
CLONE_DIR="align-ts"

source ./run-func.sh

run_func "$@"
