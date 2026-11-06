# docker-dev

Dockerfile and scripts to setup a linux dev environment pre-configured for using vim as an IDE.

## Setup

- Edit `dotfiles/gitconfig` to set your git name and email
- Modify `dotfiles/bashrc` to your taste (e.g., remove vi mode if you aren't a vi user)
- Adjust tool versions in `install/versions.env` if you need to (see [Install scripts](#install-scripts))
- Copy `settings.example` to `.settings`. Set `ADO_ORG` to enable the Azure DevOps MCP. Set `TS_AUTHKEY` if you plan to opt into the tailscale sidecar (see [Tailscale](#tailscale) below); it is not required for the default single-container setup.
- Use `./run.sh` to build and run the dev container
- On WSL, it is helpful if your user and group guid is set to 1002 to match the devuser in these containers

## Architecture

By default the dev environment runs a single container (`dev`) with standard docker bridge networking: the development environment with vim, Claude Code, etc.; ports published directly to the host (3002, 3010-3019, 6080).

```
Host (Docker Desktop)
└── Dev Container
    ├── Standard docker bridge networking
    └── Publishes ports to the host (3002, 3010-3019, 6080)
```

Pass `-t` to `run.sh` to opt into a Tailscale sidecar that owns the dev container's network namespace and provides outbound tailnet access. See [Tailscale](#tailscale) for details and trade-offs.

The image starts from plain `ubuntu:24.04`. Almost everything in it is installed by the scripts in `install/`, described next; the Dockerfile only creates the user and calls them.

## Install scripts

`install/install.sh` installs the toolset. The Dockerfile uses it to build the image, and it also works inside a running container or on top of another image. It is split into small steps, one file each under `install/steps/<group>/`, so you can install all of it or only part.

| Group | What it installs |
| --- | --- |
| base | core packages (curl, jq, sudo, ...), the en_US.UTF-8 locale, git |
| terminal | vim, tmux, fzf, ripgrep, network and database clients; the dotfiles; vim plugins and coc |
| languages | build tools and Python, node (nvm), Rust, uv, .NET, PowerShell, Rush |
| docker | docker CLI, buildx, and compose (for use with a mounted host socket) |
| cloud | GitHub CLI, Azure CLI and its DevOps extension |
| desktop | virtual display with noVNC, dbus, gnome-keyring, the MFB root certificate, Playwright browsers |
| forwarders | git credential and OAuth2 forwarder clients |
| ai | Claude Code and the claude-meta plugin, codex, Antigravity CLI, opencode, kashkeshet, Muse Code |

Run `install/install.sh --list` to see every step, which user it runs as, and what it depends on.

How a run behaves:

- **Already installed tools are skipped.** Each step first checks whether its tool is present at the version pinned in `install/versions.env`. If so, it does nothing. Dotfile steps compare the installed files with the repo's, so a rerun picks up dotfile edits.
- **Every tool is pinned.** A pin is an exact version or `latest`. With `latest`, a present tool is left alone; use `--force` to upgrade it. A variable set in the environment overrides the file for one run, e.g. `CLAUDE_VERSION=2.1.0 install/install.sh --only claude`.
- **Dependencies are added automatically.** Asking for `--only codex` also runs the `node` and `bubblewrap` steps (which skip if already done).
- **Required and optional steps.** The base and terminal steps, and node, are required: if one fails the run stops. Other steps are optional: a failure is reported in the summary at the end and the run continues. `--strict` makes every failure stop the run. The Dockerfile builds with `--strict`.
- **Root and user steps.** Run it as root, or as a user with passwordless sudo. Steps that install into a home directory run as the target user (`--user`, default: you).
- **Your shell setup is added, not replaced.** Each tool's environment (PATH, nvm, `DOTNET_ROOT`, ...) goes in its own file in `~/.docker-dev/env.d/`. `dotfiles/bashrc` is installed as `~/.docker-dev/bashrc` and loaded from the end of your existing `~/.bashrc`. Git settings are included from `~/.docker-dev/gitconfig`. An existing file the installer has to replace (like `~/.tmux.conf`) is saved once as `<name>.pre-docker-dev`.

Common uses inside the container:

```bash
install/install.sh --check                  # what is installed, at what version
install/install.sh --only ai --force        # upgrade the AI tools
install/install.sh --only claude-meta --force   # same as ~/update-claude-meta.sh
```

The image keeps a copy of the scripts in `/opt/docker-dev`, so `/opt/docker-dev/install/install.sh` works even without this repo checked out.

## Workspace Volume

Every container mounts a persistent `/workspace` directory at its root, owned by `devuser`. This is a normal Docker named volume (local driver — performant, not a bind mount) that **survives container recreation**: `docker compose down`/`up`, image rebuilds, and host reboots all leave it intact. Use it for code and data you want to keep between sessions; the rest of the container filesystem is disposable.

Each stack gets its own volume so they stay independent:

| Stack | Started by | Volume |
| --- | --- | --- |
| dev (plain + tailscale) | `run.sh` | `dev-workspace` |

The dev and tailscale stacks share `dev-workspace`, so your work is there whether or not you run with `-t`.

The volumes are declared in the compose files, so `run.sh` creates them automatically on first start — there's nothing to set up. Ownership is handled automatically: Docker seeds a fresh volume from the image's `devuser`-owned `/workspace`, so `/workspace` comes up writable by `devuser` without any manual `chown`.

### Managing the volume (`workspace.sh`)

`workspace.sh` manages the volumes out-of-band. The first argument is the target stack (`dev`, the default and only one):

```bash
./workspace.sh status [dev]                     # mountpoint, disk usage, consumers
./workspace.sh list                             # all workspace volumes
./workspace.sh create   [dev]                   # create if missing (idempotent)
./workspace.sh backup   [dev]     <file.tar.gz> # archive contents to a tarball
./workspace.sh restore  [dev]     <file.tar.gz> # restore a tarball into the volume
./workspace.sh delete   [dev]                   # remove the volume and all its data
./workspace.sh recreate [dev]                   # delete + create an empty volume
```

Add `-y` / `--yes` to skip confirmation prompts. Destructive commands (`delete`, `recreate`, `restore`) refuse to run while a container is using the volume — stop it first with `./run.sh -k`. Back up before you recreate:

```bash
./workspace.sh backup dev ~/dev-workspace.tar.gz   # snapshot first
./workspace.sh recreate dev                        # start fresh
./workspace.sh restore dev ~/dev-workspace.tar.gz  # …or roll back
```

`status`/`backup`/`restore` run a throwaway `alpine:3.19` container to read the volume; override the image with `WORKSPACE_HELPER_IMAGE` if needed.

> Note: this is a plain named volume, so its size is not capped — `du`-style usage is reported by `status`, but writes are bounded only by host disk space.

### Docker Access

By default the host's docker socket is bound into the container (from `docker-compose.docker-socket.yml`), so you (and Claude) can use the docker cli directly. Pass `-D` to `run.sh` to leave it out; the container then has no access to the host's docker daemon.

## Tailscale

The tailscale sidecar is **optional** and disabled by default. Pass `-t` to `run.sh` to enable it. The default single-container setup is more reliable on machines that change networks (e.g. laptops moving between wifi networks), since there's no sidecar holding the network namespace that can lose its connection independently of the dev container.

When enabled with `-t`, the `tailscale` sidecar gives the dev container outbound access to your tailnet, including MagicDNS resolution for peer hostnames. The dev container shares the sidecar's network namespace, so no Tailscale client is installed in the dev image itself — `curl http://my-peer:8080` and `getent hosts my-peer` just work.

```
Host (Docker Desktop)
├── Tailscale Sidecar
│   ├── Owns the shared network namespace
│   ├── Publishes ports to the host (3002, 3010-3019, 6080)
│   └── tailscale0 interface (shields-up: no inbound from peers)
│
└── Dev Container (network_mode: service:tailscale)
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

Uses `docker compose` to manage the dev container.

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

`./run.sh -D`

Don't mount the host docker socket. See [Docker Access](#docker-access).

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

## XServer

Running gui apps (e.g. chromium/electron, etc) inside docker requires an XServer on the host.

So does using clipboard transferring with `xclip`

## Keyring

Tools like `gh` save secrets in gnome-keyring. The first shell after the container starts asks for the keyring password. On the first start ever, you choose it. Press Enter to skip; the keyring then stays off, and tools fall back to their own storage. Run `keyring-unlock` to unlock it later. Other shells reuse the unlocked keyring without asking.

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
    - added 'pivot_root' to allow bubblewrap (codex's Linux sandbox) to set up
      its mount namespace

(can run strace -c to see what other syscalls are in use)

### Bubblewrap / codex sandboxing

Codex uses bubblewrap (`bwrap`) as its default Linux sandbox as of the Rust
rewrite; Landlock is now only a fallback. It probes the hardcoded path
`/usr/bin/bwrap`, warns `⚠ Codex could not find system bubblewrap at
/usr/bin/bwrap` if absent, and falls back to a vendored copy. We install the
distro `bubblewrap` package so it finds the system binary there.

Note there is no npm/nvm route for this: the npm package named `bubblewrap` is
an unrelated ES6-proxy library, and `@bubblewrap/cli` is Google's Trusted Web
Activity generator. Neither is the sandbox.

Beyond `pivot_root`, bwrap's other syscall needs (`clone`, `clone3`, `unshare`,
`setns`, `mount`, `umount2`, `capset`, `setgroups`) were already allowed, and
the socket syscalls are unfiltered, so the netlink path used by `--unshare-net`
is fine. Known runtime failure modes in constrained containers, if it does
break:

    - `bwrap: Failed RTM_NEWADDR` (openai/codex#17337)
    - `bwrap: Failed to make / slave` (openai/codex#15434)
    - unprivileged user namespaces blocked by the host kernel

The escape hatch for all of these is `codex -c use_legacy_landlock=true`.

## Chromium

Browsers come from the `playwright` step (version pinned in `install/versions.env`) and live in `~/.cache/ms-playwright`. Projects that use a different Playwright version download their own browsers with `npx playwright install`.

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
