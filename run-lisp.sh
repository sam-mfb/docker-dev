#!/bin/bash

IMAGE_TARGET="lisp-dev"
IMAGE_TAG="lisp-dev"
CONTAINER_NAME="lisp-dev-active"
DOCKER_USER_HOME="/home/devuser"
HOST_PORTS="3010"
CONTAINER_PORTS="3000"
HOSTNAME="lisp-docker"
GIT_REPO=""
CLONE_DIR=""

source ./run-func.sh

run_func "$@"
