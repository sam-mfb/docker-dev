#/bin/bash

IMAGE_TARGET="pwsh-dev-align"
IMAGE_TAG="align-pwsh-dev"
CONTAINER_NAME="align-pwsh-dev-active"
DOCKER_USER_HOME="/home/devuser"
HOST_PORTS="3003"
CONTAINER_PORTS="3000"
HOSTNAME="pwsh-docker"
GIT_REPO="git@ssh.dev.azure.com:v3/MFBTech/Syzygy%20API/align-services"
CLONE_DIR="align-services"

source ./run-func.sh

run_func "$@"
