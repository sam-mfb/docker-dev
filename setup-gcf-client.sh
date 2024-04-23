#!/bin/bash

git config --global credential.helper '!f(){ node ~/gcf-client.js $*; }; f'
git config --global credential.https://dev.azure.com.useHttpPath true
