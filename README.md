# docker-dev

## Setup

- Run ssh-add on host to add ssh id to ssh-agent for forwarding
- Assumes your .ssh directory is at the root of your home directory on your machine
- Copy your .gitconfig file into the root of this repo (will be ignored by .gitignore)
- Modify `dotfiles/bashrc` to your taste (e.g., remove vi mode if you aren't a vi user)
- Use the existing `run-ts.sh` or `run-dotnet` scripts or create your own `run-[x].sh` script based on them

## run-[x].sh scripts

### Variables

```bash
# Image target in Dockerfile
IMAGE_TARGET="ts-dev"
# Tag for image that will be built on host
IMAGE_TAG="align-ts-dev"
# Name of container that will be run from image
CONTAINER_NAME="align-ts-dev-active"
# Name of non-root user (in container, not host) that will be used in container
DOCKER_USER_HOME="/home/devuser"
# Port or range of ports to be proxied on host
HOST_PORTS="3000"
# Port or range of ports to be proxied from container
CONTAINER_PORTS="3000"
# Container hostname
HOSTNAME="ts-docker"
# Git repository
GIT_REPO="git@ssh.dev.azure.com:v3/Fabrikam/some-repo"
# Directory to clone into
CLONE_DIR="some-repo"
```

### Usage

`./run-[x].sh`

Builds image and runs the container. If image is already build that is used. If container already exists that is used.

`./run-x.sh -k`

Delete existing container (make sure there's nothing on there you wanted to save!)

`./run-x.sh -r`

Delete existing image

`./run-x.sh -x`

Delete both container and image
