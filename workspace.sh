#!/bin/bash
# workspace.sh -- manage the per-stack /workspace named volumes.
#
# Each dev stack gets its own persistent Docker named volume mounted at
# /workspace inside the container, owned by devuser. These are normal local
# named volumes (performant, not bind mounts) that survive container
# recreation -- docker compose up/down, image rebuilds, host reboots. This
# script manages their lifecycle out-of-band: inspect usage, back up / restore,
# delete, and recreate.
#
#   dev  -> dev-workspace  (run.sh; shared by the plain and tailscale stacks)
#   exp  -> exp-workspace  (run-exp.sh)
#
# docker compose already auto-creates these on first `up`, so for normal use
# you don't need this script at all -- it's for managing the volumes directly.

set -euo pipefail

LABEL_KEY="com.docker-dev.workspace"
# Throwaway image used for du / tar over the volume. alpine:3.19 is already
# cached by the exp-proxy build stage; override with WORKSPACE_HELPER_IMAGE if
# you prefer a different small image.
HELPER_IMAGE="${WORKSPACE_HELPER_IMAGE:-alpine:3.19}"
ASSUME_YES=false

die() { echo "Error: $*" >&2; exit 1; }

# Map a target name (dev|exp) to its volume name.
vol_for() {
    case "${1:-dev}" in
        dev) echo "dev-workspace" ;;
        exp) echo "exp-workspace" ;;
        *)   die "unknown target '$1' (expected: dev or exp)" ;;
    esac
}

vol_exists() { docker volume inspect "$1" >/dev/null 2>&1; }

# Create the volume with its management label if it isn't there already.
ensure_volume() {
    local vol="$1" target="$2"
    vol_exists "$vol" || docker volume create --label "${LABEL_KEY}=${target}" "$vol" >/dev/null
}

# Abort if any running container is currently using the volume.
require_not_in_use() {
    local vol="$1" running
    running=$(docker ps --filter "volume=$vol" --format '{{.Names}}')
    if [ -n "$running" ]; then
        echo "Volume '$vol' is in use by running container(s):" >&2
        echo "$running" | sed 's/^/  - /' >&2
        die "stop them first (e.g. ./run.sh -k or ./run-exp.sh -k)"
    fi
}

confirm() {
    [ "$ASSUME_YES" = true ] && return 0
    local ans
    read -r -p "$1 [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]]
}

cmd_create() {
    local target="${1:-dev}" vol
    vol=$(vol_for "$target")
    if vol_exists "$vol"; then
        echo "Volume '$vol' already exists."
        return 0
    fi
    docker volume create --label "${LABEL_KEY}=${target}" "$vol" >/dev/null
    echo "Created volume '$vol'. It will be owned by devuser on next container start."
}

cmd_status() {
    local target="${1:-dev}" vol mountpoint usage users
    vol=$(vol_for "$target")
    vol_exists "$vol" || die "volume '$vol' does not exist (run: ./workspace.sh create $target)"
    mountpoint=$(docker volume inspect -f '{{.Mountpoint}}' "$vol")
    usage=$(docker run --rm -v "$vol":/w "$HELPER_IMAGE" du -sh /w 2>/dev/null | cut -f1)
    echo "Volume:     $vol"
    echo "Mountpoint: $mountpoint"
    echo "Usage:      ${usage:-unknown}"
    users=$(docker ps -a --filter "volume=$vol" --format '{{.Names}} ({{.State}})')
    if [ -n "$users" ]; then
        echo "In use by:"
        echo "$users" | sed 's/^/  - /'
    else
        echo "In use by:  (none)"
    fi
}

cmd_list() {
    echo "Workspace volumes:"
    docker volume ls --filter "label=${LABEL_KEY}" --format '  {{.Name}}'
}

cmd_backup() {
    local target="${1:-dev}" out="${2:-}" vol outdir outbase
    vol=$(vol_for "$target")
    vol_exists "$vol" || die "volume '$vol' does not exist"
    [ -n "$out" ] || die "usage: ./workspace.sh backup <target> <file.tar.gz>"
    mkdir -p "$(dirname "$out")"
    outdir=$(cd "$(dirname "$out")" && pwd)
    outbase=$(basename "$out")
    docker run --rm -v "$vol":/w:ro -v "$outdir":/backup "$HELPER_IMAGE" \
        tar czf "/backup/$outbase" -C /w .
    echo "Backed up '$vol' -> $outdir/$outbase"
}

cmd_restore() {
    local target="${1:-dev}" in="${2:-}" vol indir inbase
    vol=$(vol_for "$target")
    [ -n "$in" ] || die "usage: ./workspace.sh restore <target> <file.tar.gz>"
    [ -f "$in" ] || die "backup file '$in' not found"
    require_not_in_use "$vol"
    ensure_volume "$vol" "$target"
    indir=$(cd "$(dirname "$in")" && pwd)
    inbase=$(basename "$in")
    docker run --rm -v "$vol":/w -v "$indir":/backup:ro -e F="$inbase" "$HELPER_IMAGE" \
        sh -c 'tar xzf "/backup/$F" -C /w'
    echo "Restored $indir/$inbase -> '$vol'"
}

cmd_delete() {
    local target="${1:-dev}" vol
    vol=$(vol_for "$target")
    vol_exists "$vol" || { echo "Volume '$vol' does not exist."; return 0; }
    require_not_in_use "$vol"
    confirm "Delete volume '$vol' and ALL its data?" || { echo "Aborted."; return 0; }
    docker volume rm "$vol" >/dev/null
    echo "Deleted volume '$vol'."
}

cmd_recreate() {
    local target="${1:-dev}" vol
    vol=$(vol_for "$target")
    require_not_in_use "$vol"
    if vol_exists "$vol"; then
        confirm "Recreate volume '$vol'? This DELETES all current data (back up first with: ./workspace.sh backup $target <file>)." \
            || { echo "Aborted."; return 0; }
        docker volume rm "$vol" >/dev/null
    fi
    docker volume create --label "${LABEL_KEY}=${target}" "$vol" >/dev/null
    echo "Recreated empty volume '$vol'. It will be owned by devuser on next container start."
}

usage() {
cat <<'EOF'
workspace.sh -- manage per-stack /workspace named volumes

Usage: ./workspace.sh <command> [target] [args] [-y]

Targets:
  dev   dev-workspace   (default; run.sh, plain + tailscale stacks)
  exp   exp-workspace   (run-exp.sh)

Commands:
  status   [target]                 show mountpoint, disk usage, and consumers
  list                              list all workspace volumes
  create   [target]                 create the volume if missing (idempotent)
  ensure   [target]                 alias for create
  backup   [target] <file.tar.gz>   archive the volume contents to a tarball
  restore  [target] <file.tar.gz>   restore a tarball into the volume
  delete   [target]                 remove the volume and all its data
  recreate [target]                 delete + create an empty volume

Options:
  -y, --yes    skip confirmation prompts

Notes:
  * Volumes are normal Docker named volumes (local driver) and persist across
    container recreation. docker compose also auto-creates them on first `up`.
  * Destructive commands refuse to run while a container is using the volume;
    stop it first (./run.sh -k or ./run-exp.sh -k). Back up before recreate.
EOF
}

main() {
    local args=()
    for a in "$@"; do
        case "$a" in
            -y|--yes) ASSUME_YES=true ;;
            *) args+=("$a") ;;
        esac
    done
    set -- "${args[@]+"${args[@]}"}"

    local cmd="${1:-}"
    [ $# -gt 0 ] && shift
    case "$cmd" in
        status)         cmd_status "$@" ;;
        list)           cmd_list "$@" ;;
        create|ensure)  cmd_create "$@" ;;
        backup)         cmd_backup "$@" ;;
        restore)        cmd_restore "$@" ;;
        delete|destroy) cmd_delete "$@" ;;
        recreate)       cmd_recreate "$@" ;;
        ""|-h|--help|help) usage ;;
        *) usage; echo; die "unknown command '$cmd'" ;;
    esac
}

main "$@"
