STEP_DESC="Trust the MFB root certificate in the browser certificate store"
STEP_RUN_AS=user
STEP_OPTIONAL=1
STEP_REQUIRES="x11"

DB="sql:$HOME/.pki/nssdb"
NICK=mfb-root

step_check()   { certutil -L -d "$DB" -n "$NICK" >/dev/null 2>&1; }
step_version() { step_check && echo "$NICK"; }
step_install() {
    mkdir -p "$HOME/.pki/nssdb"
    [ -f "$HOME/.pki/nssdb/cert9.db" ] || certutil -N --empty-password -d "$DB"
    certutil -A -d "$DB" -t "C,," -n "$NICK" -i "$DD_ROOT/mfb-root-certificate.crt"
}
