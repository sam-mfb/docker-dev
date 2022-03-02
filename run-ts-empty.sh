#/bin/bash

IMAGE_TARGET="ts-dev"
IMAGE_TAG="ts-dev"
CONTAINER_NAME="ts-dev-active"
DOCKER_USER_HOME="/home/devuser"
HOST_PORTS="3000"
CONTAINER_PORTS="3000"
HOSTNAME="ts-docker-empty"
GIT_REPO=""
CLONE_DIR=""

source ./run-func.sh

run_func "$@"
