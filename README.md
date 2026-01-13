# docker-dev

Dockerfile and scripts to setup a linux dev environment pre-configured for using vim as an IDE. 

See the old2025 branch for other images, e.g., lisp, Swift (both using coc-nvim) and C#/.NET Core (using omnisharp-vim).

## Setup

- Run `ssh-add` on host to add ssh id to ssh-agent for forwarding
- Assumes your `.ssh` directory is at the root of your home directory on your machine
- Copy your `.gitconfig` file into the root of this repo (will not be committed to version control)
- Modify `dotfiles/bashrc` to your taste (e.g., remove vi mode if you aren't a vi user)
- Use `./run.sh` to build and run the dev container
- On WSL, it is helpful if your user and group guid is set to 1002 to match the devuser in these containers

## run.sh

### Usage

`./run.sh`

Builds image and runs the container. If image is already built that is used. If container already exists that is used.

`./run.sh -k`

Delete existing container (make sure there's nothing on there you wanted to save!)

`./run.sh -r`

Delete existing image

`./run.sh -x`

Delete both container and image

`./run.sh -b`

Force rebuild the image with --no-cache

`./run.sh -h`

Mount host home directory to /host-home in the container

### Mounting Additional Volumes

You can mount additional Docker volumes by setting the `DOCKER_VOLUMES` environment variable:

```bash
# Single volume
DOCKER_VOLUMES="myvolume:/app/data" ./run.sh

# Multiple volumes (comma-separated)
DOCKER_VOLUMES="vol1:/data1,vol2:/data2,vol3:/data3:ro" ./run.sh

# Named volumes or bind mounts
DOCKER_VOLUMES="/host/path:/container/path,named-volume:/app/storage" ./run.sh
```

## XServer

Running gui apps (e.g. chromium/electron, etc) inside docker requires an XServer on the host.

So does using clipboard transferring with `xclip`

And, it is easier to have it running to use gnome-keyring. It is possible to pass gnome-keyring a password from stdin but i'd have to write some util to get the password in a secure fashion. 

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
