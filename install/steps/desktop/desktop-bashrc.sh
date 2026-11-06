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

# Session bus, used by browsers and the keyring. Started once per container;
# later shells (tmux panes, docker exec) find it running and reuse it.
if [ -z "$NO_DBUS_CONFIG" ] && command -v dbus-daemon >/dev/null; then
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
    if ! dbus-send --session --print-reply --dest=org.freedesktop.DBus / \
            org.freedesktop.DBus.GetId >/dev/null 2>&1; then
        if sudo -n true 2>/dev/null; then
            sudo service dbus start >/dev/null 2>&1
            [ -d "$XDG_RUNTIME_DIR" ] || sudo install -d -m 0700 -o "$(id -u)" "$XDG_RUNTIME_DIR"
        fi
        if [ -d "$XDG_RUNTIME_DIR" ] && [ -w "$XDG_RUNTIME_DIR" ]; then
            # A new bus means a new container start: forget an earlier skip.
            rm -f "$XDG_RUNTIME_DIR/bus" "$XDG_RUNTIME_DIR/keyring-skipped"
            dbus-daemon --session --address="$DBUS_SESSION_BUS_ADDRESS" \
                --fork --nopidfile --syslog-only >/dev/null 2>&1
        fi
    fi
fi

# Keyring (gnome-keyring), where gh and other tools save secrets. It is
# protected by a password that you type here once per container start. A locked
# keyring would open a password window on the virtual display, where nobody sees
# it, and hang whatever asked. So the keyring runs only once it is unlocked; if
# you skip, tools find no keyring and fall back to their own storage. Run
# keyring-unlock to unlock it later.
_dd_keyring_unlocked() {
    local r
    r=$(timeout 5 dbus-send --session --print-reply --dest=org.freedesktop.secrets \
        /org/freedesktop/secrets/collection/login org.freedesktop.DBus.Properties.Get \
        string:org.freedesktop.Secret.Collection string:Locked 2>/dev/null) || return 1
    [[ "$r" == *"boolean false"* ]]
}

keyring-unlock() {
    command -v gnome-keyring-daemon >/dev/null || { echo "gnome-keyring is not installed"; return 1; }
    [ -w "${XDG_RUNTIME_DIR:-}" ] || { echo "no session bus; cannot start the keyring"; return 1; }
    # One prompt at a time, even when several shells start together.
    local pw pw2 new=
    exec 9>"$XDG_RUNTIME_DIR/keyring.lock"
    flock 9
    # Called at shell start: another shell may have skipped while this one waited.
    if [ "${1:-}" = --auto ] && [ -e "$XDG_RUNTIME_DIR/keyring-skipped" ]; then
        flock -u 9; exec 9>&-; return 0
    fi
    rm -f "$XDG_RUNTIME_DIR/keyring-skipped"
    if pgrep -u "$(id -u)" -x gnome-keyring-d >/dev/null && _dd_keyring_unlocked; then
        flock -u 9; exec 9>&-; return 0
    fi
    [ -f "$HOME/.local/share/keyrings/login.keyring" ] || new=1
    while :; do
        pkill -u "$(id -u)" -x gnome-keyring-d 2>/dev/null && sleep 0.3
        if [ -n "$new" ]; then
            read -rsp "Choose a keyring password (Enter to skip): " pw; echo
            if [ -n "$pw" ]; then
                read -rsp "Type it again: " pw2; echo
                [ "$pw" = "$pw2" ] || { echo "The passwords differ."; continue; }
            fi
        else
            read -rsp "Keyring password (Enter to skip): " pw; echo
        fi
        if [ -z "$pw" ]; then
            touch "$XDG_RUNTIME_DIR/keyring-skipped"
            echo "Keyring not started. Run keyring-unlock to start it."
            break
        fi
        printf '%s' "$pw" | gnome-keyring-daemon --daemonize --unlock \
            --components=secrets >/dev/null 2>&1
        sleep 0.3
        if _dd_keyring_unlocked; then
            echo "Keyring unlocked."
            break
        fi
        echo "Wrong password."
        new=
    done
    pw= pw2=
    if ! _dd_keyring_unlocked; then
        pkill -u "$(id -u)" -x gnome-keyring-d 2>/dev/null
    fi
    flock -u 9; exec 9>&-
}

if [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ] && command -v gnome-keyring-daemon >/dev/null \
        && [ -t 0 ] && [ ! -e "$XDG_RUNTIME_DIR/keyring-skipped" ] \
        && ! { pgrep -u "$(id -u)" -x gnome-keyring-d >/dev/null && _dd_keyring_unlocked; }; then
    keyring-unlock --auto
fi
