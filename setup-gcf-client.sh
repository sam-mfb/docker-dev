#!/bin/bash
# Point git at the git credential forwarder client (gcf-client). Run again
# after VS Code attaches, since it replaces the credential helper.

HELPER='!f(){ gcf-client $*; }; f'

# VS Code writes its helper at both the system and global level, so replace
# both. The system level needs root.
if [ "$(id -u)" -eq 0 ]; then
    git config --system --replace-all credential.helper "$HELPER"
elif sudo -n true 2>/dev/null; then
    sudo git config --system --replace-all credential.helper "$HELPER"
else
    echo "No sudo; leaving the system-level git credential helper alone." >&2
fi

git config --global --replace-all credential.helper "$HELPER"
git config --global credential.https://dev.azure.com.useHttpPath true
