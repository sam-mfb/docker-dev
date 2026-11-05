#!/usr/bin/env bash
# install.sh -- install the docker-dev toolset into an image or a running
# container.
#
# The setup is split into steps, one file each, under steps/<group>/. Steps run
# in group order, then file order. Each step first checks whether its tool is
# already present at the pinned version (see versions.env) and skips if so.
#
# Usage: install.sh [options]
#   --only LIST    comma-separated groups or step names to run (default: all)
#   --skip LIST    groups or step names to leave out
#   --user NAME    user to set up (default: the user who ran sudo, else you)
#   --force        reinstall the selected steps even if already present
#   --strict       stop at the first failure, optional steps included
#   --check        install nothing; report what is present and its version
#   --list         list groups and steps
#   -h, --help     show this help
#
# Steps a selected step depends on are added automatically, before it.
# Required steps stop the run when they fail. Optional steps only warn, and a
# summary at the end lists what failed, unless --strict is given.
#
# Run it as root, or as a user with passwordless sudo (it re-runs itself under
# sudo). Steps marked "user" run as the target user.

set -uo pipefail

DD_INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DD_ROOT="$(dirname "$DD_INSTALL_DIR")"
GROUP_ORDER=(base terminal languages docker cloud desktop forwarders ai)

# --- Single-step mode ----------------------------------------------------------
#
# install.sh runs each step by calling itself with --_step FILE ACTION, as the
# right user, so steps get a clean process with only the variables they need.

if [ "${1:-}" = "--_step" ]; then
    file="$2" action="$3"
    # shellcheck source=lib.sh
    . "$DD_INSTALL_DIR/lib.sh"
    load_user_env
    # Keep vim and other X-aware tools from reaching for a display mid-install.
    unset DISPLAY
    # shellcheck disable=SC1090
    . "$file"
    case "$action" in
        check)   step_check ;;
        version) step_version 2>/dev/null ;;
        install) set -eo pipefail; step_install ;;
        *) echo "unknown step action: $action" >&2; exit 2 ;;
    esac
    exit $?
fi

usage() { sed -n '2,/^$/{s/^# \{0,1\}//;p}' "${BASH_SOURCE[0]}"; }

ONLY="" SKIP="" TARGET_USER="" FORCE=0 STRICT=0 MODE=install
while [ $# -gt 0 ]; do
    case "$1" in
        --only)   ONLY="${2:?--only needs a list}"; shift ;;
        --skip)   SKIP="${2:?--skip needs a list}"; shift ;;
        --user)   TARGET_USER="${2:?--user needs a name}"; shift ;;
        --force)  FORCE=1 ;;
        --strict) STRICT=1 ;;
        --check)  MODE=check ;;
        --list)   MODE=list ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

# --- Step discovery ------------------------------------------------------------

declare -a STEPS=()                  # step names, in run order
declare -A S_FILE S_GROUP S_AS S_REQ S_OPT S_DESC

step_name() { local b; b="$(basename "$1" .sh)"; echo "${b#[0-9][0-9]-}"; }

for group in "${GROUP_ORDER[@]}"; do
    for file in "$DD_INSTALL_DIR/steps/$group"/[0-9][0-9]-*.sh; do
        [ -e "$file" ] || continue
        name="$(step_name "$file")"
        [ -z "${S_FILE[$name]:-}" ] || { echo "duplicate step name: $name" >&2; exit 2; }
        IFS='|' read -r as req opt desc < <(
            STEP_RUN_AS=root STEP_REQUIRES="" STEP_OPTIONAL=0 STEP_DESC=""
            # shellcheck disable=SC1090
            . "$file"
            echo "$STEP_RUN_AS|$STEP_REQUIRES|$STEP_OPTIONAL|$STEP_DESC")
        STEPS+=("$name")
        S_FILE[$name]="$file" S_GROUP[$name]="$group" S_AS[$name]="$as"
        S_REQ[$name]="$req" S_OPT[$name]="$opt" S_DESC[$name]="$desc"
    done
done

if [ "$MODE" = list ]; then
    for name in "${STEPS[@]}"; do
        printf '%-11s %-26s %-5s %-9s %s\n' "${S_GROUP[$name]}" "$name" "${S_AS[$name]}" \
            "$([ "${S_OPT[$name]}" = 1 ] && echo optional || echo required)" "${S_DESC[$name]}"
    done
    exit 0
fi

# --- Selection -----------------------------------------------------------------

in_list() { [[ ",$2," == *",$1,"* ]]; }

matches() {   # matches NAME LIST -- step named directly or through its group
    in_list "$1" "$2" || in_list "${S_GROUP[$1]}" "$2"
}

for item in ${ONLY//,/ } ${SKIP//,/ }; do
    known=0
    for g in "${GROUP_ORDER[@]}"; do [ "$g" = "$item" ] && known=1; done
    [ -n "${S_FILE[$item]:-}" ] && known=1
    [ $known = 1 ] || { echo "unknown group or step: $item (see --list)" >&2; exit 2; }
done

declare -A EXPLICIT WANTED
for name in "${STEPS[@]}"; do
    { [ -z "$ONLY" ] || matches "$name" "$ONLY"; } || continue
    { [ -n "$SKIP" ] && matches "$name" "$SKIP"; } && continue
    EXPLICIT[$name]=1
done

add_with_deps() {
    local name="$1" dep
    [ -n "${WANTED[$name]:-}" ] && return
    WANTED[$name]=1
    for dep in ${S_REQ[$name]}; do
        [ -n "${S_FILE[$dep]:-}" ] || { echo "step $name needs unknown step $dep" >&2; exit 2; }
        add_with_deps "$dep"
    done
}
for name in "${!EXPLICIT[@]}"; do add_with_deps "$name"; done

# Dependencies normally come earlier in group/file order. Where one doesn't
# (e.g. a terminal step needing node from languages), move it ahead.
declare -a ORDER=()
declare -A PLACED
place() {
    local name="$1" dep
    [ -n "${PLACED[$name]:-}" ] && return
    PLACED[$name]=1
    for dep in ${S_REQ[$name]}; do place "$dep"; done
    ORDER+=("$name")
}
for name in "${STEPS[@]}"; do [ -n "${WANTED[$name]:-}" ] && place "$name"; done

[ ${#ORDER[@]} -gt 0 ] || { echo "nothing selected" >&2; exit 2; }

# --- Privileges and target user ------------------------------------------------

if [ "$(id -u)" -ne 0 ]; then
    if sudo -n true 2>/dev/null; then
        args=(--user "${TARGET_USER:-$(id -un)}")
        [ -n "$ONLY" ] && args+=(--only "$ONLY")
        [ -n "$SKIP" ] && args+=(--skip "$SKIP")
        [ $FORCE = 1 ] && args+=(--force)
        [ $STRICT = 1 ] && args+=(--strict)
        [ $MODE = check ] && args+=(--check)
        # Pass version overrides from the caller's environment through sudo.
        envs=()
        while IFS='=' read -r k _; do
            [ -n "${!k+x}" ] && envs+=("$k=${!k}")
        done < <(grep -E '^[A-Z0-9_]+=' "$DD_INSTALL_DIR/versions.env")
        exec sudo -n env "${envs[@]}" "$0" "${args[@]}"
    fi
    # Checking only reads, so it can run as you without sudo.
    if [ "$MODE" != check ]; then
        echo "install.sh needs root, or passwordless sudo." >&2
        exit 1
    fi
    if [ -n "$TARGET_USER" ] && [ "$TARGET_USER" != "$(id -un)" ]; then
        echo "--check for another user needs root." >&2
        exit 1
    fi
fi

if [ "$(id -u)" -eq 0 ]; then
    TARGET_USER="${TARGET_USER:-${SUDO_USER:-root}}"
else
    TARGET_USER="$(id -un)"
fi
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
[ -n "$TARGET_HOME" ] || { echo "no such user: $TARGET_USER" >&2; exit 2; }
TARGET_UID="$(id -u "$TARGET_USER")"

# --- Versions ------------------------------------------------------------------
#
# versions.env gives every pin. A variable already set in the environment wins,
# so `CLAUDE_VERSION=2.1.0 install.sh --only claude` works for one-off pins.

VERSION_VARS=()
while IFS= read -r line; do
    [[ "$line" =~ ^([A-Z0-9_]+)=(.*)$ ]] || continue
    k="${BASH_REMATCH[1]}" v="${BASH_REMATCH[2]}"
    v="${v%%#*}"; v="${v%"${v##*[![:space:]]}"}"; v="${v%\"}"; v="${v#\"}"
    [ -n "${!k+x}" ] || printf -v "$k" '%s' "$v"
    VERSION_VARS+=("$k=${!k}")
done < "$DD_INSTALL_DIR/versions.env"

DD_RUN_DIR="$(mktemp -d /tmp/docker-dev-install.XXXXXX)"
chmod 0777 "$DD_RUN_DIR"
trap 'rm -rf "$DD_RUN_DIR"' EXIT

# step_exec NAME ACTION -- run one step function as the step's user.
step_exec() {
    local name="$1" action="$2" force=0
    [ $FORCE = 1 ] && [ -n "${EXPLICIT[$name]:-}" ] && force=1
    local env_vars=(
        "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
        "TERM=${TERM:-xterm-256color}" "LANG=${LANG:-C.UTF-8}"
        "DD_ROOT=$DD_ROOT" "DD_INSTALL_DIR=$DD_INSTALL_DIR" "DD_RUN_DIR=$DD_RUN_DIR"
        "DD_TARGET_USER=$TARGET_USER" "DD_TARGET_HOME=$TARGET_HOME"
        "DD_TARGET_UID=$TARGET_UID" "DD_FORCE=$force"
        "${VERSION_VARS[@]}"
    )
    local k
    for k in http_proxy https_proxy no_proxy HTTP_PROXY HTTPS_PROXY NO_PROXY; do
        [ -n "${!k:-}" ] && env_vars+=("$k=${!k}")
    done
    if [ "$(id -u)" -ne 0 ]; then
        (cd "$TARGET_HOME" && env -i HOME="$TARGET_HOME" USER="$TARGET_USER" LOGNAME="$TARGET_USER" \
            "${env_vars[@]}" bash "$DD_INSTALL_DIR/install.sh" --_step "${S_FILE[$name]}" "$action")
    elif [ "${S_AS[$name]}" = user ] && [ "$TARGET_USER" != root ]; then
        (cd "$TARGET_HOME" && runuser -u "$TARGET_USER" -- env -i \
            HOME="$TARGET_HOME" USER="$TARGET_USER" LOGNAME="$TARGET_USER" \
            "${env_vars[@]}" bash "$DD_INSTALL_DIR/install.sh" --_step "${S_FILE[$name]}" "$action")
    else
        local home=/root
        [ "${S_AS[$name]}" = user ] && home="$TARGET_HOME"
        (cd / && env -i HOME="$home" USER=root LOGNAME=root "${env_vars[@]}" \
            bash "$DD_INSTALL_DIR/install.sh" --_step "${S_FILE[$name]}" "$action")
    fi
}

step_version_of() { step_exec "$1" version 2>/dev/null | head -n1; }

# --- Check mode ----------------------------------------------------------------

if [ "$MODE" = check ]; then
    printf '%-11s %-26s %-8s %s\n' GROUP STEP STATUS VERSION
    missing=0
    for name in "${ORDER[@]}"; do
        if step_exec "$name" check >/dev/null 2>&1; then status=ok; else status=missing; missing=1; fi
        printf '%-11s %-26s %-8s %s\n' "${S_GROUP[$name]}" "$name" "$status" "$(step_version_of "$name")"
    done
    exit $missing
fi

# --- Install mode --------------------------------------------------------------

declare -A RESULT
failed_optional=()
echo "docker-dev install: user=$TARGET_USER steps=${#ORDER[@]}"

for name in "${ORDER[@]}"; do
    label="${S_GROUP[$name]}/$name"
    blocked=""
    for dep in ${S_REQ[$name]}; do
        case "${RESULT[$dep]:-}" in present|installed) ;; *) blocked="$dep" ;; esac
    done
    if [ -n "$blocked" ]; then
        echo "==> $label: skipped, needs $blocked"
        RESULT[$name]="blocked"
    elif { [ $FORCE = 0 ] || [ -z "${EXPLICIT[$name]:-}" ]; } \
            && step_exec "$name" check >/dev/null 2>&1; then
        echo "==> $label: already present"
        RESULT[$name]="present"
    else
        echo "==> $label: ${S_DESC[$name]}"
        if step_exec "$name" install && step_exec "$name" check >/dev/null 2>&1; then
            RESULT[$name]="installed"
        else
            echo "==> $label: FAILED"
            RESULT[$name]="failed"
        fi
    fi

    case "${RESULT[$name]}" in failed|blocked)
        if [ $STRICT = 1 ] || [ "${S_OPT[$name]}" != 1 ]; then
            echo "Stopping: required step $label did not install." >&2
            exit 1
        fi
        failed_optional+=("$label (${RESULT[$name]})")
    esac
done

echo
echo "Summary:"
for name in "${ORDER[@]}"; do
    v=""
    case "${RESULT[$name]}" in present|installed) v="$(step_version_of "$name")" ;; esac
    printf '  %-11s %-26s %-10s %s\n' "${S_GROUP[$name]}" "$name" "${RESULT[$name]}" "$v"
done
if [ ${#failed_optional[@]} -gt 0 ]; then
    echo
    echo "Optional steps that did not install:"
    printf '  %s\n' "${failed_optional[@]}"
fi
exit 0
