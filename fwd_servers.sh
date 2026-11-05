#!/bin/bash

# Name of the tmux session
SESSION_NAME="node_fwd_servers"

# Server commands (with environment variables included)
SERVER1_COMMAND="export GIT_CREDENTIAL_FORWARDER_PORT=38274 && gcf-server"
SERVER2_COMMAND="export OAUTH2_FORWARDER_PORT=48272 && export OAUTH2_FORWARDER_PASSTHROUGH=true && o2f-server"

confirm() {
    local answer
    read -r -p "$1 [y/N] " answer
    case "$answer" in
        [yY]|[yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

# The forwarders are npm packages, so npm (and node) must exist first.
# Offer to install Node.js via Homebrew when it is missing.
ensure_npm() {
    command -v npm >/dev/null 2>&1 && return 0

    echo "npm is not installed; it is needed to install the forwarders."
    if command -v brew >/dev/null 2>&1; then
        if confirm "Install Node.js (includes npm) with Homebrew now?"; then
            brew install node && return 0
        fi
    else
        echo "Install Node.js from https://nodejs.org/ and re-run this script."
    fi
    return 1
}

# Check each forwarder package for a newer version on npm and offer to
# install or upgrade it. Never installs without an explicit "y".
check_for_update() {
    local pkg="$1"
    local installed latest

    installed=$(npm ls -g --depth=0 --parseable --long "$pkg" 2>/dev/null \
        | sed -n "s/.*:$pkg@\(.*\)$/\1/p" | head -n 1)
    latest=$(npm view "$pkg" version 2>/dev/null)

    if [ -z "$installed" ]; then
        if [ -n "$latest" ]; then
            echo "$pkg is not installed globally (latest is $latest)."
            confirm "Install $pkg@$latest now?" && npm install -g "$pkg@$latest"
        else
            echo "$pkg is not installed globally (could not reach npm to check the latest version)."
            confirm "Try installing $pkg now?" && npm install -g "$pkg"
        fi
        return
    fi
    if [ -z "$latest" ]; then
        echo "Could not check npm for the latest version of $pkg (installed: $installed); skipping."
        return
    fi
    if [ "$installed" = "$latest" ]; then
        echo "$pkg is up to date ($installed)."
        return
    else
        echo "$pkg: installed $installed, latest $latest."
        if confirm "Upgrade $pkg to $latest?"; then
            npm install -g "$pkg@$latest"
        else
            echo "Leaving $pkg as is."
        fi
    fi
}

if ensure_npm; then
    check_for_update git-credential-forwarder
    check_for_update oauth2-forwarder
fi

# Don't start tmux with servers that would just fail with "command not found".
missing=""
for bin in gcf-server o2f-server; do
    command -v "$bin" >/dev/null 2>&1 || missing="$missing $bin"
done
if [ -n "$missing" ]; then
    echo "Cannot start the forwarders; missing:$missing" >&2
    exit 1
fi

# Start a new tmux session
tmux new-session -d -s "$SESSION_NAME"

# Split the tmux session into two panes
tmux send-keys -t "$SESSION_NAME:0.0" "$SERVER1_COMMAND" C-m
tmux split-window -h -t "$SESSION_NAME:0"
tmux send-keys -t "$SESSION_NAME:0.1" "$SERVER2_COMMAND" C-m

# Attach to the tmux session
tmux attach -t "$SESSION_NAME"
