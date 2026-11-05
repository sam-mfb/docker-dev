STEP_DESC="PowerShell"
STEP_RUN_AS=root
STEP_OPTIONAL=1
STEP_REQUIRES="packages build-tools"

PWSH_DIR=/opt/microsoft/powershell/7

step_version() { pwsh --version 2>/dev/null | awk '{print $2}'; }
step_check()   { has pwsh && version_matches "$PWSH_VERSION" "$(step_version)"; }
step_install() {
    local v="$PWSH_VERSION"
    is_latest "$v" && v="$(github_latest_tag PowerShell/PowerShell)"
    v="${v#v}"
    local tarball="$DD_RUN_DIR/powershell.tar.gz"
    download "https://github.com/PowerShell/PowerShell/releases/download/v$v/powershell-$v-linux-$(release_arch).tar.gz" "$tarball"
    rm -rf "$PWSH_DIR"
    mkdir -p "$PWSH_DIR"
    tar -xzf "$tarball" -C "$PWSH_DIR"
    chmod +x "$PWSH_DIR/pwsh"
    ln -sf "$PWSH_DIR/pwsh" /usr/bin/pwsh
    # Not run here: installing these modules is slow. Run it by hand if needed.
    install -m 0644 "$DD_ROOT/InstallPSMods.ps1" /opt/microsoft/powershell/InstallPSMods.ps1
}
