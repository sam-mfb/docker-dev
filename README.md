# docker-dev

Dockerfile and scripts to setup a linux dev environment pre-configured for using vim as an IDE.

## Setup

- Copy your `.gitconfig` file into the root of this repo (will not be committed to version control)
- Modify `dotfiles/bashrc` to your taste (e.g., remove vi mode if you aren't a vi user)
- Copy `settings.example` to `.settings`. Set `ADO_ORG` to enable the Azure DevOps MCP. Set `TS_AUTHKEY` if you plan to opt into the tailscale sidecar (see [Tailscale](#tailscale) below); it is not required for the default single-container setup.
- Use `./run.sh` to build and run the dev container
- On WSL, it is helpful if your user and group guid is set to 1002 to match the devuser in these containers

## Architecture

By default the dev environment runs a single container with standard docker bridge networking, plus an MCP gateway started on the host by `run.sh`:

1. **MCP Gateway** (host process) - Provides Docker access to Claude via MCP servers, listening on `localhost:8811`
2. **Dev Container** (`dev`) - The development environment with vim, Claude Code, etc.; ports published directly to the host (3002, 3010-3019, 6080)

```
Host (Docker Desktop)
├── MCP Gateway (host process on :8811)
│
└── Dev Container
    ├── Standard docker bridge networking
    ├── Publishes ports to the host (3002, 3010-3019, 6080)
    └── Claude Code (connects to gateway via MCP)
```

Pass `-t` to `run.sh` to opt into a Tailscale sidecar that owns the dev container's network namespace and provides outbound tailnet access. See [Tailscale](#tailscale) for details and trade-offs.

### Docker Access via Claude

Inside the container, Claude has access to Docker through MCP servers:

- **docker** - Run Docker CLI commands
- **dockerhub** - Search and manage Docker Hub images

Use `/mcp` in Claude to verify the connection. Then ask Claude to run Docker commands like "list running containers" or "search Docker Hub for nginx images".

### Docker Access outside of Claude

The docker socket is also bound into the container. Claude will not use it (it will use the MCP), but you can use the docker cli directly.

The host's .docker/mcp directory is mounted as well which allows you to use `docker mcp` commands to configure the gateway from inside the container. Note any secrets that you set will saved on your host.

## Tailscale

The tailscale sidecar is **optional** and disabled by default. Pass `-t` to `run.sh` to enable it. The default single-container setup is more reliable on machines that change networks (e.g. laptops moving between wifi networks), since there's no sidecar holding the network namespace that can lose its connection independently of the dev container.

When enabled with `-t`, the `tailscale` sidecar gives the dev container outbound access to your tailnet, including MagicDNS resolution for peer hostnames. The dev container shares the sidecar's network namespace, so no Tailscale client is installed in the dev image itself — `curl http://my-peer:8080` and `getent hosts my-peer` just work.

```
Host (Docker Desktop)
├── MCP Gateway (host process on :8811)
│
├── Tailscale Sidecar
│   ├── Owns the shared network namespace
│   ├── Publishes ports to the host (3002, 3010-3019, 6080)
│   └── tailscale0 interface (shields-up: no inbound from peers)
│
└── Dev Container (network_mode: service:tailscale)
    ├── Claude Code (connects to gateway via MCP)
    ├── Reaches tailnet peers by MagicDNS name
    └── Shares loopback + interfaces with the sidecar
```

### Setup

Generate a reusable, ephemeral auth key at <https://login.tailscale.com/admin/settings/keys> and put it in `.settings`:

```sh
TS_AUTHKEY="tskey-auth-..."
```

Then start with `./run.sh -t`. The sidecar registers in your tailnet using `HOSTNAME` (default `sam-dev`) as its device name. Tailscale state persists in the `tailscale-state` named volume, so the device doesn't re-register on every run. `docker compose down -v` would wipe it.

`-t` requires `TS_AUTHKEY` to be set; otherwise `run.sh` exits with an error. Omit `-t` to run without the sidecar.

### Inbound is blocked (shields-up)

The sidecar runs with `--shields-up`, which blocks all inbound connections from tailnet peers. Outbound connections and MagicDNS still work. Host port publishing (e.g. `localhost:3002`) is unaffected because that traffic arrives on the sidecar's docker bridge interface, not on `tailscale0`.

If a process in the dev container binds to `0.0.0.0`, shields-up is what prevents it from being reachable from the tailnet. Bind to `127.0.0.1` if you want to be doubly sure.

### Network namespace sharing

Because `dev` uses `network_mode: service:tailscale`:

- All `ports:` declarations live on the `tailscale` service, not `dev`.
- `localhost` inside dev reaches anything tailscaled is listening on, and vice versa. Avoid port collisions with tailscaled's local API.
- `/etc/resolv.conf` in dev points at tailscaled's resolver — that's how MagicDNS works.
- `ip addr` in dev shows the sidecar's interfaces, including `tailscale0`.
- If the sidecar restarts, the dev container loses its network until both come back. `./run.sh` recovers.

### Kernel vs userspace mode

The sidecar uses kernel networking (`TS_USERSPACE=false`) which requires `/dev/net/tun` and `NET_ADMIN`/`NET_RAW` caps. This works out of the box on Docker Desktop (Mac, Windows, WSL) because Docker's Linux VM ships with the `tun` module.

If you ever run on an engine that doesn't expose `/dev/net/tun` (some Colima/Lima profiles, minimal Linux hosts), flip `TS_USERSPACE=true` in `docker-compose.tailscale.yml` and drop the tun mount + caps. In userspace mode there's no `tailscale0` interface, so apps reach the tailnet via tailscaled's SOCKS5 proxy on `localhost:1055` (`ALL_PROXY=socks5h://localhost:1055`).

## run.sh

Uses `docker compose` to manage both the MCP gateway and dev container.

### Usage

`./run.sh`

Builds image and starts both containers. If already running, attaches to the dev container.

`./run.sh -k`

Stop and remove both containers (make sure there's nothing on there you wanted to save!)

`./run.sh -r`

Delete existing image

`./run.sh -x`

Stop containers and delete image

`./run.sh -b`

Force rebuild the image with --no-cache

`./run.sh -t`

Run with the tailscale sidecar for outbound tailnet access. Requires `TS_AUTHKEY` to be set in `.settings`. Without `-t`, the dev container runs standalone with standard docker bridge networking (the default).

`./run.sh -h`

Mount host home directory to /host-home in the container

`./run.sh -m <path>`

Bind mount a host directory into the container at `/host-mnt<path>`. The path is resolved to an absolute path. Can be specified multiple times to mount several directories.

```bash
# Mount a single directory
./run.sh -m /Users/sam/projects

# This mounts /Users/sam/projects on the host to /host-mnt/Users/sam/projects in the container

# Mount multiple directories
./run.sh -m /Users/sam/projects -m /Users/sam/data

# Combine with other flags
./run.sh -h -m /Users/sam/projects
```

### Mounting Additional Volumes

For full control over volume syntax (named volumes, read-only mounts, custom container paths), use the `DOCKER_VOLUMES` environment variable:

```bash
# Single volume
DOCKER_VOLUMES="myvolume:/app/data" ./run.sh

# Multiple volumes (comma-separated)
DOCKER_VOLUMES="vol1:/data1,vol2:/data2,vol3:/data3:ro" ./run.sh

# Named volumes or bind mounts
DOCKER_VOLUMES="/host/path:/container/path,named-volume:/app/storage" ./run.sh
```

## Experimental Container (run-exp.sh)

An isolated container for running Claude Code in YOLO mode with restricted host access. Uses Docker network-level isolation that cannot be bypassed from inside the container (unlike iptables rules which can be flushed with sudo).

Inside the container, the `claude-yolo` alias runs Claude Code with `--dangerously-skip-permissions`.

### How it works

The experimental container sits on a Docker `internal: true` network with no gateway -- it has no direct route to the host or internet. A lightweight proxy sidecar (alpine + tinyproxy/socat/dnsmasq) bridges the internal and external networks:

- **Internet access** via HTTP/HTTPS proxy (tinyproxy on the sidecar)
- **OAuth2 forwarding** via TCP pipe to host port 48272 only (socat on the sidecar)
- **DNS resolution** via DNS forwarder (dnsmasq on the sidecar)
- **Host access blocked** by iptables on the proxy sidecar (separate container, unreachable from exp)

What's restricted vs the dev container:
- No Docker socket
- No host volume mounts
- No git credential forwarding (port 38274 is unreachable)
- No X11 display
- No MCP gateway

### Usage

`./run-exp.sh`

Builds both images (main + proxy sidecar) and starts the containers. If already running, attaches to the exp container.

`./run-exp.sh -k`

Stop and remove both containers.

`./run-exp.sh -r`

Delete both images.

`./run-exp.sh -x`

Stop both containers and delete both images.

`./run-exp.sh -b`

Force rebuild both images with --no-cache.

### Limitations

- Tools that don't respect `HTTP_PROXY`/`HTTPS_PROXY` will fail to connect (fail-closed, which is the intended security behavior)
- Use HTTPS git URLs -- git over SSH won't work through the HTTP proxy
- Authenticate git via `gh auth login --web` (uses the OAuth2 forwarder) then `gh auth setup-git`

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
