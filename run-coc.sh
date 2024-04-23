#!/bin/bash

IMAGE_TARGET="coc-dev"
IMAGE_TAG="coc-dev"
CONTAINER_NAME="coc-dev-active"
DOCKER_USER_HOME="/home/devuser"
HOST_PORTS="3010"
CONTAINER_PORTS="3000"
HOSTNAME="coc-docker"
GIT_REPO=""
CLONE_DIR=""

source ./run-func.sh

run_func "$@"
