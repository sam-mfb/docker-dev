STEP_DESC="bubblewrap, the sandbox codex runs commands in"
STEP_RUN_AS=root
STEP_OPTIONAL=1
STEP_REQUIRES="packages"

# codex looks for it at exactly /usr/bin/bwrap, which is where the distro
# package puts it. See the Bubblewrap section of README.md.
step_check()   { [ -x /usr/bin/bwrap ]; }
step_version() { /usr/bin/bwrap --version 2>/dev/null | awk '{print $2}'; }
step_install() { apt_install bubblewrap; }
