STEP_DESC="Virtual display with noVNC, dbus, and gnome-keyring"
STEP_RUN_AS=root
STEP_OPTIONAL=1
STEP_REQUIRES="packages"

PKGS=(xvfb x11vnc novnc websockify autocutsel x11-utils xclip xdg-utils dbus-x11
      gnome-keyring libsecret-1-0 libsecret-tools libnss3-tools upower
      gstreamer1.0-gl gstreamer1.0-plugins-ugly)

step_check()   {
    apt_all_installed "${PKGS[@]}" \
        && [ -f "$DD_TARGET_HOME/.local/share/dbus-1/services/org.freedesktop.secrets.service" ]
}
step_version() { dpkg-query -W -f='xvfb ${Version}' xvfb 2>/dev/null; }
step_install() {
    apt_install "${PKGS[@]}"

    # Xvfb runs as the user, so its socket directory must already exist.
    mkdir -p /tmp/.X11-unix && chmod 1777 /tmp/.X11-unix
    # Runtime directory for the session bus and keyring.
    install -d -m 0700 -o "$DD_TARGET_UID" "/run/user/$DD_TARGET_UID"

    write_env desktop <<'EOT'
export DISPLAY="${DISPLAY:-:99}"
export VNC_RESOLUTION="${VNC_RESOLUTION:-1280x1024x24}"
export VNC_PORT="${VNC_PORT:-5900}"
export NOVNC_PORT="${NOVNC_PORT:-6080}"
export NO_AT_BRIDGE=1
EOT
    install -m 0644 "$DD_INSTALL_DIR/steps/desktop/desktop-bashrc.sh" \
        "$DD_TARGET_HOME/.docker-dev/bashrc.d/desktop.sh"
    own "$DD_TARGET_HOME/.docker-dev/bashrc.d/desktop.sh"

    # Stop the session bus from starting the keyring on demand. Started that
    # way it is locked, and it opens a password window nobody can see. The
    # shell starts it instead, once unlocked (see desktop-bashrc.sh). Files in
    # the user's dbus-1/services directory take precedence over the system ones.
    local svc="$DD_TARGET_HOME/.local/share/dbus-1/services" name
    install -d -o "$DD_TARGET_USER" "$DD_TARGET_HOME/.local" "$DD_TARGET_HOME/.local/share"
    mkdir -p "$svc"
    for name in org.freedesktop.secrets org.gnome.keyring; do
        printf '[D-BUS Service]\nName=%s\nExec=/bin/false\n' "$name" > "$svc/$name.service"
    done
    own "$DD_TARGET_HOME/.local/share/dbus-1"
}
