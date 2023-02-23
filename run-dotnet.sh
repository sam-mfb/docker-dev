#/bin/sh

IMAGE_TARGET="dotnet-dev"
IMAGE_TAG="align-services-dev"
CONTAINER_NAME="align-services-dev-active"
DOCKER_USER_HOME="/home/devuser"
HOST_PORTS="12000-12004"
CONTAINER_PORTS="12000-12004"
HOSTNAME="dotnet-docker"
GIT_REPO="git@ssh.dev.azure.com:v3/MFBTech/Syzygy%20API/align-services"
CLONE_DIR="align-services"

source ./run-func.sh

run_func "$@"
