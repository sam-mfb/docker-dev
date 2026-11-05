# lib.sh -- helpers shared by install.sh and every step.
#
# Sourced, never run. Steps run in their own process, either as root or as the
# target user, with these variables set by install.sh:
#
#   DD_ROOT          repo root (holds install/, dotfiles/, and other assets)
#   DD_INSTALL_DIR   $DD_ROOT/install
#   DD_RUN_DIR       scratch dir for this run, removed when install.sh exits
#   DD_TARGET_USER   user the setup is for; DD_TARGET_HOME, DD_TARGET_UID too
#   DD_FORCE         1 when the step was named explicitly with --force
#   *_VERSION        pins from versions.env (or the caller's environment)

# --- Logging -----------------------------------------------------------------

log()  { printf '    %s\n' "$*"; }
warn() { printf '    WARNING: %s\n' "$*" >&2; }
die()  { printf '    ERROR: %s\n' "$*" >&2; exit 1; }

has() { command -v "$1" >/dev/null 2>&1; }

# --- Versions ----------------------------------------------------------------

is_latest() { [ -z "${1:-}" ] || [ "$1" = "latest" ]; }

# version_matches PIN ACTUAL
# True when PIN is "latest", or ACTUAL equals PIN, or ACTUAL starts with PIN
# followed by a dot (so a pin of "10.0" accepts "10.0.103").
version_matches() {
    local pin="$1" actual="$2"
    is_latest "$pin" && return 0
    [ -n "$actual" ] || return 1
    pin="${pin#v}"; actual="${actual#v}"
    [ "$actual" = "$pin" ] || [ "${actual#"$pin".}" != "$actual" ]
}

# first_version TEXT -- pull the first x.y[.z] number out of a version banner.
first_version() { grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' <<<"$1" | head -n1; }

# --- Platform ----------------------------------------------------------------

os_id()       { . /etc/os-release 2>/dev/null; echo "${ID:-unknown}"; }
os_codename() { . /etc/os-release 2>/dev/null; echo "${VERSION_CODENAME:-}"; }
is_apt()      { has apt-get && has dpkg; }
deb_arch()    { dpkg --print-architecture; }   # amd64 | arm64

# x64 | arm64, the naming most release archives use.
release_arch() {
    case "$(uname -m)" in
        x86_64|amd64)  echo x64 ;;
        aarch64|arm64) echo arm64 ;;
        *) die "unsupported CPU architecture: $(uname -m)" ;;
    esac
}

require_apt() {
    is_apt || die "this step needs apt (Debian or Ubuntu); found $(os_id)"
}

# --- Downloads ---------------------------------------------------------------

CURL_OPTS=(-fsSL --retry 5 --retry-delay 3 --retry-all-errors --connect-timeout 20)

# fetch URL -- print the body. Fails on any HTTP error rather than returning an
# error page.
fetch() { curl "${CURL_OPTS[@]}" "$1"; }

# download URL DEST
download() { curl "${CURL_OPTS[@]}" -o "$2" "$1"; }

# run_installer URL [ARGS...] -- download an install script to a file first,
# then run it, so a dropped connection can't run half a script.
run_installer() {
    local url="$1"; shift
    local script
    script="$(mktemp "$DD_RUN_DIR/installer.XXXXXX")"
    download "$url" "$script"
    bash "$script" "$@"
}

# github_latest_tag OWNER/REPO -- tag of the newest release. Reads the
# releases/latest redirect, which avoids the API's rate limit.
github_latest_tag() {
    local url
    url="$(curl "${CURL_OPTS[@]}" -o /dev/null -w '%{url_effective}' \
        "https://github.com/$1/releases/latest")" || return 1
    [[ "$url" == */releases/tag/* ]] || { warn "no releases found for $1"; return 1; }
    echo "${url##*/}"
}

# --- apt ---------------------------------------------------------------------

export DEBIAN_FRONTEND=noninteractive

# Refresh package lists at most once per run, or again after a source changes.
apt_update() {
    local stamp="$DD_RUN_DIR/apt-updated"
    [ -f "$stamp" ] && return 0
    apt-get update -q && touch "$stamp"
}

apt_installed() { dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'install ok installed'; }

apt_all_installed() {
    local p
    for p in "$@"; do apt_installed "$p" || return 1; done
}

# apt_install PKG... -- install only the packages that are missing.
apt_install() {
    require_apt
    local p missing=()
    for p in "$@"; do apt_installed "$p" || missing+=("$p"); done
    [ ${#missing[@]} -eq 0 ] && return 0
    apt_update
    log "apt: installing ${missing[*]}"
    apt-get install -y -q "${missing[@]}"
}

# apt_install_pinned PKG PIN -- latest, or the newest available version whose
# upstream part starts with PIN (epochs like "5:" and suffixes like "-1~noble"
# are ignored).
apt_install_pinned() {
    local pkg="$1" pin="$2" ver
    require_apt
    apt_update
    if is_latest "$pin"; then
        apt-get install -y -q "$pkg"
        return
    fi
    ver="$(apt-cache madison "$pkg" | awk -F'|' '{gsub(/ /,"",$2); print $2}' \
        | grep -E "^([0-9]+:)?${pin//./\\.}([.~+-]|$)" | head -n1)"
    [ -n "$ver" ] || die "no $pkg version matching '$pin' in apt sources"
    apt-get install -y -q --allow-downgrades "$pkg=$ver"
}

# apt_pkg_version PKG -- installed upstream version, without epoch or suffix.
apt_pkg_version() {
    dpkg-query -W -f='${Version}' "$1" 2>/dev/null | sed -E 's/^[0-9]+://; s/[-~+].*$//'
}

# apt_add_source NAME KEY_URL "deb ... line" -- add a signed apt source. The
# line may use {keyring}, which is replaced with the key's path.
apt_add_source() {
    local name="$1" key_url="$2" line="$3"
    local keyring="/etc/apt/keyrings/$name.gpg" list="/etc/apt/sources.list.d/$name.list"
    require_apt
    apt_install ca-certificates curl gnupg
    install -d -m 0755 /etc/apt/keyrings
    if [ ! -s "$keyring" ]; then
        fetch "$key_url" | gpg --dearmor --yes -o "$keyring"
        chmod go+r "$keyring"
    fi
    line="${line//\{keyring\}/$keyring}"
    if [ "$(cat "$list" 2>/dev/null)" != "$line" ]; then
        echo "$line" > "$list"
        rm -f "$DD_RUN_DIR/apt-updated"
    fi
}

# --- Target user's shell setup -------------------------------------------------
#
# Each step that needs environment variables or PATH entries writes its own
# file under ~/.docker-dev/env.d/. Interactive shell additions go in
# ~/.docker-dev/bashrc.d/. ~/.docker-dev/env.sh loads every env.d file and is
# sourced by the shell (via ~/.docker-dev/bashrc) and by user steps.

dd_dir() { echo "$DD_TARGET_HOME/.docker-dev"; }

# Give a path we created to the target user when running as root.
own() { [ "$(id -u)" -eq 0 ] && chown -R "$DD_TARGET_USER:" "$@" || true; }

ensure_env_loader() {
    local dir; dir="$(dd_dir)"
    mkdir -p "$dir/env.d" "$dir/bashrc.d"
    cat > "$dir/env.sh" <<'EOF'
# Generated by docker-dev install.sh. Loads every file in env.d.
dd_path_prepend() { case ":$PATH:" in *":$1:"*) ;; *) PATH="$1:$PATH" ;; esac; }
dd_path_append()  { case ":$PATH:" in *":$1:"*) ;; *) PATH="$PATH:$1" ;; esac; }
for _dd_f in "$HOME"/.docker-dev/env.d/*.sh; do
    [ -r "$_dd_f" ] && . "$_dd_f"
done
unset _dd_f
export PATH
EOF
    own "$dir"
}

# write_env NAME <<'EOF' ... EOF -- install an env.d file from stdin.
write_env() {
    ensure_env_loader
    cat > "$(dd_dir)/env.d/$1.sh"
    own "$(dd_dir)/env.d/$1.sh"
}

# write_bashrc NAME <<'EOF' ... EOF -- install a bashrc.d file from stdin.
write_bashrc() {
    ensure_env_loader
    cat > "$(dd_dir)/bashrc.d/$1.sh"
    own "$(dd_dir)/bashrc.d/$1.sh"
}

# load_user_env -- make tools installed by earlier steps visible. nvm's script
# fails under `set -eu`, so relax both while loading.
load_user_env() {
    local f="$HOME/.docker-dev/env.sh"
    [ -r "$f" ] || return 0
    local opts=$-
    set +eu
    . "$f"
    [[ $opts == *e* ]] && set -e
    [[ $opts == *u* ]] && set -u
    return 0
}

# --- Files -------------------------------------------------------------------

# same_file A B -- true when both exist with identical contents.
same_file() { [ -f "$1" ] && [ -f "$2" ] && cmp -s "$1" "$2"; }

# place_file SRC DEST [MODE] -- copy SRC to DEST. Paths we have placed before
# are listed in ~/.docker-dev/placed; any other existing DEST (say, the base
# image's own .tmux.conf) is saved once as DEST.pre-docker-dev first.
place_file() {
    local src="$1" dest="$2" mode="${3:-0644}" list
    list="$(dd_dir)/placed"
    same_file "$src" "$dest" && return 0
    if [ -e "$dest" ] && ! grep -qxF "$dest" "$list" 2>/dev/null \
            && [ ! -e "$dest.pre-docker-dev" ]; then
        log "saving existing $dest as $dest.pre-docker-dev"
        cp -p "$dest" "$dest.pre-docker-dev"
    fi
    mkdir -p "$(dirname "$dest")" "$(dd_dir)"
    install -m "$mode" "$src" "$dest"
    grep -qxF "$dest" "$list" 2>/dev/null || echo "$dest" >> "$list"
    own "$dest" "$list"
}

# --- npm ---------------------------------------------------------------------

# Make `npm install -g` work without root. nvm's prefix is already the user's;
# a system node (e.g. /usr/local) gets a per-user prefix instead.
npm_ensure_user_prefix() {
    local prefix
    prefix="$(npm prefix -g)"
    [ -w "$prefix/lib" ] || [ -w "$prefix" ] && return 0
    log "npm global prefix $prefix is not writable; using ~/.npm-global"
    npm config set prefix "$HOME/.npm-global"
    mkdir -p "$HOME/.npm-global"
    write_env npm-global <<'EOF'
dd_path_prepend "$HOME/.npm-global/bin"
EOF
    export PATH="$HOME/.npm-global/bin:$PATH"
}

# npm_global_version PKG -- installed version of a global package, or nothing.
npm_global_version() {
    has npm || return 0
    npm ls -g --depth 0 --json "$1" 2>/dev/null \
        | jq -r --arg p "$1" '.dependencies[$p].version // empty'
}

# npm_global_install PKG PIN
npm_global_install() {
    has npm || die "npm not found"
    npm_ensure_user_prefix
    local spec="$1@latest"
    is_latest "$2" || spec="$1@$2"
    log "npm: installing $spec"
    npm install -g --no-fund --no-audit "$spec"
}

# npm_global_check PKG PIN -- installed and matching the pin.
npm_global_check() {
    local v; v="$(npm_global_version "$1")"
    [ -n "$v" ] && version_matches "$2" "$v"
}
