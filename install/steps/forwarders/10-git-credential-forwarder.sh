STEP_DESC="git credential forwarder client, which asks the host for git credentials"
STEP_RUN_AS=user
STEP_OPTIONAL=1
STEP_REQUIRES="node git"

step_version() { npm_global_version git-credential-forwarder; }
step_check() {
    npm_global_check git-credential-forwarder "$GCF_VERSION" &&
    same_file "$DD_ROOT/setup-gcf-client.sh" "$HOME/setup-gcf-client.sh" &&
    git config --global --get credential.helper | grep -q gcf-client
}
step_install() {
    npm_global_install git-credential-forwarder "$GCF_VERSION"
    place_file "$DD_ROOT/setup-gcf-client.sh" "$HOME/setup-gcf-client.sh" 0755
    bash "$HOME/setup-gcf-client.sh"
    write_env git-credential-forwarder <<'EOT'
export GIT_CREDENTIAL_FORWARDER_SERVER="${GIT_CREDENTIAL_FORWARDER_SERVER:-host.docker.internal:38274}"
EOT
}
