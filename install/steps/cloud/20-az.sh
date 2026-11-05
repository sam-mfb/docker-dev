STEP_DESC="Azure CLI"
STEP_RUN_AS=root
STEP_OPTIONAL=1
STEP_REQUIRES="packages"

step_version() { apt_pkg_version azure-cli; }
step_check()   { has az && version_matches "$AZ_VERSION" "$(step_version)"; }
step_install() {
    apt_add_source microsoft-azure-cli https://packages.microsoft.com/keys/microsoft.asc \
        "deb [arch=$(deb_arch) signed-by={keyring}] https://packages.microsoft.com/repos/azure-cli/ $(os_codename) main"
    apt_install_pinned azure-cli "$AZ_VERSION"
}
