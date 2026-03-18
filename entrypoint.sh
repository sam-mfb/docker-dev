#!/bin/bash
set -e

# Start Xvfb on display :99
Xvfb ${DISPLAY} -screen 0 ${VNC_RESOLUTION:-1280x1024x24} -ac +extension GLX +render -noreset &
sleep 1

# Sync X CLIPBOARD and PRIMARY selections so that:
#   - vim/tmux yanks (CLIPBOARD) are visible to VNC (PRIMARY)
#   - noVNC pastes (PRIMARY) are visible to xclip (CLIPBOARD)
autocutsel -fork
autocutsel -selection PRIMARY -fork

# Start x11vnc (no password — localhost only)
x11vnc -display ${DISPLAY} -forever -shared -rfbport ${VNC_PORT:-5900} -nopw &
sleep 0.5

# Start noVNC via websockify
websockify --web /usr/share/novnc ${NOVNC_PORT:-6080} localhost:${VNC_PORT:-5900} &
sleep 0.5

echo "noVNC available at http://localhost:${NOVNC_PORT:-6080}/vnc.html"

# Exec passed command or bash
if [[ $# -eq 0 ]]; then exec bash; else exec "$@"; fi
