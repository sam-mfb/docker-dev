#/bin/sh

IMAGE_TARGET="dotnet-dev-x64"
IMAGE_TAG="align-services-dev-x64"
CONTAINER_NAME="align-services-dev-active-x64"
DOCKER_USER_HOME="/home/devuser"
HOST_PORTS="12000-12050"
CONTAINER_PORTS="12000-12050"
HOSTNAME="dotnet-docker-x64"
GIT_REPO="git@ssh.dev.azure.com:v3/MFBTech/Syzygy%20API/align-services"
CLONE_DIR="align-services"

source ./run-func.sh

run_func "$@"
