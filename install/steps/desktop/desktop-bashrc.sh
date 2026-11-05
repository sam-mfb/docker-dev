# Installed by the desktop step into ~/.docker-dev/bashrc.d/.

# Start the virtual display and noVNC once per container.
if [ -n "$DISPLAY" ] && command -v Xvfb >/dev/null && ! pgrep -x Xvfb >/dev/null 2>&1; then
    Xvfb "$DISPLAY" -screen 0 "$VNC_RESOLUTION" -ac +extension GLX +render -noreset &
    for _i in $(seq 1 50); do
        xdpyinfo -display "$DISPLAY" >/dev/null 2>&1 && break
        sleep 0.1
    done
    unset _i
    x11vnc -display "$DISPLAY" -forever -shared -rfbport "$VNC_PORT" -nopw >/dev/null 2>&1 &
    sleep 0.5
    websockify --web /usr/share/novnc "$NOVNC_PORT" "localhost:$VNC_PORT" >/dev/null 2>&1 &
    # Keep the X CLIPBOARD and PRIMARY selections in sync for vim, tmux, and VNC.
    autocutsel &
    autocutsel -selection PRIMARY &
    echo "noVNC available at http://localhost:$NOVNC_PORT/vnc.html"
fi

# Session bus and keyring, used by browsers and libsecret. Skipped inside tmux,
# where the outer shell has already started them.
if [ -z "$TMUX" ] && [ -z "$NO_DBUS_CONFIG" ] && command -v dbus-daemon >/dev/null; then
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
    if sudo -n true 2>/dev/null; then
        sudo service dbus start >/dev/null 2>&1
        [ -d "$XDG_RUNTIME_DIR" ] || sudo install -d -m 0700 -o "$(id -u)" "$XDG_RUNTIME_DIR"
    fi
    if [ -d "$XDG_RUNTIME_DIR" ] && [ -w "$XDG_RUNTIME_DIR" ]; then
        dbus-daemon --session --address="$DBUS_SESSION_BUS_ADDRESS" --nofork --nopidfile --syslog-only &
        echo "Logging gnome-keyring-daemon messages to /tmp/gnome-keyring.log"
        gnome-keyring-daemon --start --components=secrets &> /tmp/gnome-keyring.log
    fi
fi
