#!/bin/bash

# Ensure the /workspace named volume is owned by us. Normally Docker seeds a
# fresh volume from the image's /workspace, but a volume pre-created by
# workspace.sh comes up root-owned -- fix the top level here.
if [ -d /workspace ] && [ "$(stat -c %u /workspace 2>/dev/null)" != "$(id -u)" ]; then
    sudo chown "$(id -u):$(id -g)" /workspace 2>/dev/null || true
fi

# Start the virtual display and noVNC if the desktop group is installed.
if [ -n "$DISPLAY" ] && command -v Xvfb >/dev/null; then
    Xvfb "$DISPLAY" -screen 0 "${VNC_RESOLUTION:-1280x1024x24}" -ac +extension GLX +render -noreset &

    # Wait for Xvfb to be ready (up to 5s)
    for i in $(seq 1 50); do
        xdpyinfo -display "$DISPLAY" > /dev/null 2>&1 && break
        sleep 0.1
    done

    # x11vnc (no password -- localhost only), then noVNC via websockify
    x11vnc -display "$DISPLAY" -forever -shared -rfbport "${VNC_PORT:-5900}" -nopw &
    sleep 0.5
    websockify --web /usr/share/novnc "${NOVNC_PORT:-6080}" "localhost:${VNC_PORT:-5900}" &
    sleep 0.5

    # Sync X CLIPBOARD and PRIMARY selections so that:
    #   - vim/tmux yanks (CLIPBOARD) are visible to VNC (PRIMARY)
    #   - noVNC pastes (PRIMARY) are visible to xclip (CLIPBOARD)
    autocutsel &
    autocutsel -selection PRIMARY &

    echo "noVNC available at http://localhost:${NOVNC_PORT:-6080}/vnc.html"
fi

# Exec passed command or bash
if [[ $# -eq 0 ]]; then exec bash; else exec "$@"; fi
