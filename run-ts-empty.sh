#/bin/bash

IMAGE_TARGET="ts-dev"
IMAGE_TAG="ts-dev-empty"
CONTAINER_NAME="ts-dev-empty-active"
DOCKER_USER_HOME="/home/devuser"
HOST_PORTS="3010"
CONTAINER_PORTS="3000"
HOSTNAME="ts-docker-empty"
GIT_REPO=""
CLONE_DIR=""

source ./run-func.sh

run_func "$@"
