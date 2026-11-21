STEP_DESC="Command-line utilities: tmux, fzf, ripgrep, network tools, plain vim"
STEP_RUN_AS=root
STEP_REQUIRES="packages"

# vim: a plain fallback editor; Neovim is the configured one (25-neovim.sh).
PKGS=(vim tmux fzf ripgrep xclip nano openssh-client sqlite3 postgresql-client
      uuid-runtime iputils-ping dnsutils traceroute mtr-tiny netcat-openbsd net-tools
      telnet tcpdump iptables man-db)

step_check()   { apt_all_installed "${PKGS[@]}"; }
step_version() { tmux -V 2>/dev/null; }
step_install() { apt_install "${PKGS[@]}"; }
