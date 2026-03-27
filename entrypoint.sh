#!/bin/bash

# Start Xvfb on display :99
Xvfb ${DISPLAY} -screen 0 ${VNC_RESOLUTION:-1280x1024x24} -ac +extension GLX +render -noreset &

# Wait for Xvfb to be ready (up to 5s)
for i in $(seq 1 50); do
    xdpyinfo -display ${DISPLAY} > /dev/null 2>&1 && break
    sleep 0.1
done

# Sync X CLIPBOARD and PRIMARY selections so that:
#   - vim/tmux yanks (CLIPBOARD) are visible to VNC (PRIMARY)
#   - noVNC pastes (PRIMARY) are visible to xclip (CLIPBOARD)
autocutsel -fork || echo "Warning: autocutsel (CLIPBOARD) failed to start"
autocutsel -selection PRIMARY -fork || echo "Warning: autocutsel (PRIMARY) failed to start"

# Start x11vnc (no password — localhost only)
x11vnc -display ${DISPLAY} -forever -shared -rfbport ${VNC_PORT:-5900} -nopw &
sleep 0.5

# Start noVNC via websockify
websockify --web /usr/share/novnc ${NOVNC_PORT:-6080} localhost:${VNC_PORT:-5900} &
sleep 0.5

echo "noVNC available at http://localhost:${NOVNC_PORT:-6080}/vnc.html"

# Exec passed command or bash
if [[ $# -eq 0 ]]; then exec bash; else exec "$@"; fi
