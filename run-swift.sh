#/bin/bash

IMAGE_TARGET="swift-base"
IMAGE_TAG="swift-base-dev"
CONTAINER_NAME="swift-base-dev-active"
DOCKER_USER_HOME="/home/devuser"
HOST_PORTS="30000"
CONTAINER_PORTS="30000"
HOSTNAME="swift-docker"
GIT_REPO=""
CLONE_DIR=""

source ./run-func.sh

run_func "$@"
