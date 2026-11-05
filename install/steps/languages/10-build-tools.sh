STEP_DESC="Compilers, Python, and libraries that language toolchains build against"
STEP_RUN_AS=root
STEP_OPTIONAL=1
STEP_REQUIRES="packages"

# libicu: .NET and PowerShell. cairo/pango/jpeg/gif/rsvg: node-canvas.
# libsecret: native keychain modules such as keytar.
PKGS=(build-essential pkg-config python3 python3-pip python3-venv python3-setuptools
      pipx libicu-dev libcairo2-dev libpango1.0-dev libjpeg-dev libgif-dev
      librsvg2-dev libsecret-1-dev)

step_check()   { apt_all_installed "${PKGS[@]}"; }
step_version() { gcc --version 2>/dev/null | head -n1 | awk '{print "gcc", $NF}'; }
step_install() { apt_install "${PKGS[@]}"; }
