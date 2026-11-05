STEP_DESC="Command-line utilities: vim, tmux, fzf, ripgrep, network tools"
STEP_RUN_AS=root
STEP_REQUIRES="packages"

PKGS=(vim-gtk3 tmux fzf ripgrep xclip nano openssh-client sqlite3 postgresql-client
      uuid-runtime iputils-ping dnsutils traceroute mtr-tiny netcat-openbsd net-tools
      telnet tcpdump iptables man-db)

step_check()   { apt_all_installed "${PKGS[@]}"; }
step_version() { vim --version 2>/dev/null | head -n1 | awk '{print "vim", $5}'; }
step_install() { apt_install "${PKGS[@]}"; }
