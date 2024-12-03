# docker-dev

Dockerfile and scripts to setup a linux dev environment pre-configured for using vim as an IDE. Currently has images for TypeScript, Swift (both using coc-nvim) and C#/.NET Core (using omnisharp-vim).

The base image has the following installed

1. D2 Docs v0.6.3 for creating diagrams in markdown files
2. Python v3
3. Vim
4. SQLite v3
5. Azure CLI
6. Powershell v7
7. Latest .NET
8. Git Credential Manager

## Setup

- Run `ssh-add` on host to add ssh id to ssh-agent for forwarding
- Assumes your `.ssh` directory is at the root of your home directory on your machine
- Copy your `.gitconfig` file into the root of this repo (will not be committed to version control)
- Modify `dotfiles/bashrc` to your taste (e.g., remove vi mode if you aren't a vi user)
- Use the existing `run-[x]` scripts or create your own `run-[x].sh` script based on them
- On WSL, it is helpful if your user and group guid is set to 1002 to match the devuser in these containers

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

## XServer

Running gui apps (e.g. chromium/electron, etc) inside docker requires an XServer on the host.

So does using clipboard transferring with `xclip`

### On Mac --

- Install XQuartz via `brew install --cask xquartz`
- Launch via `open -a XQuartz`
- Set preferences in XQuartz to "Allow connections from network clients"
- Restart the mac
- Start XQuartz
- Run /usr/bin/X11/xhost +localhost

NB: On mac, once you have XQuartz setup properly the run tasks will automatically start it

### On Windows --

- Install Cygwin/X (cygwin installer and choose xinit and xhost)
- Change the XWin Server shortcut to add `-- -listen tcp` as a command option
- Start XWin Server (allow private network access only)
- In Cygwin terminal run: `DISPLAY=localhost:0.0 xhost +localhost`

## Seccomp

Using the chrome.js seccomp profile, with the following modifications:

    - added `statx` syscall to this to allow proper use of `ls`
    - added 'copy-file-range' to allow copying files
    - added 'ptrace' to allow using strace
    - added 'faccesssat2' to allow tmux to create streams
    - added 'rseq' and 'close_range" to allow WebKit gtk browser to run
    - added 'clone3' to allow pthread creation on Windows

(can run strace -c to see what other syscalls are in use)

## Chromium

- Call with `--disable-gpu` to get rid of graphics warnings.
- Call with `--window-size=1280,1024` or similar to set window size
- Set shm size to 2gb via docker run. Alternatively, call with `--disable-dev-shm-usage` to avoid crashes from too small shm size

### Git and Oauth2 forwarders

To use the git and oauth2 forwarders, on your host you'll need to start them and, ideally, setup the corresponding env variables automatically. For example, on a mac in .zprofile

```sh
export GIT_CREDENTIAL_FORWARDER_PORT=38272
export OAUTH2_FORWARDER_PORT=48272
```

They can both be started in a single tmux session by running `./fwd_servers.sh`

VS Code can clobber the setup needed for these to work. To re-enable, in the container run:

```bash
~/setup-gcf-client.sh
source ~/.browser_env
```
