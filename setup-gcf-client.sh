#!/bin/bash

# this line is needed to overwrite vscode which writes its helper to both places
sudo git config --system --replace-all credential.helper '!f(){ node ~/gcf-client.js $*; }; f'

git config --global --replace-all credential.helper '!f(){ node ~/gcf-client.js $*; }; f'
git config --global credential.https://dev.azure.com.useHttpPath true
