STEP_DESC="Core packages every other step relies on"
STEP_RUN_AS=root

PKGS=(ca-certificates curl wget gnupg lsb-release sudo locales jq unzip xz-utils
      zip less procps file bash-completion)

step_check()   { apt_all_installed "${PKGS[@]}"; }
step_version() { lsb_release -ds 2>/dev/null || os_id; }
step_install() { apt_install "${PKGS[@]}"; }
