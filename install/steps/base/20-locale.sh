STEP_DESC="Generate the en_US.UTF-8 locale"
STEP_RUN_AS=root
STEP_REQUIRES="packages"

step_check()   { locale -a 2>/dev/null | grep -qi '^en_US\.utf-\?8$'; }
step_version() { echo en_US.UTF-8; }
step_install() {
    sed -i '/en_US.UTF-8/s/^# //' /etc/locale.gen
    grep -q '^en_US.UTF-8' /etc/locale.gen || echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
    locale-gen
    write_env locale <<'EOT'
export LANG="${LANG:-en_US.UTF-8}"
export LANGUAGE="${LANGUAGE:-en_US:en}"
EOT
}
