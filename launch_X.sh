#!/bin/bash

# Check if the operating system is macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo "This script is designed to run on macOS only."
    exit 1
fi

# Check if XQuartz is installed
if ! command -v Xquartz &> /dev/null && ! command -v xterm &> /dev/null; then
    echo "XQuartz is not installed."
    echo "You can install XQuartz from: https://www.xquartz.org/"
    echo "After installation, please rerun this script."
    exit 1
fi

echo "Launching XQuartz (if not open already)..."
open -a XQuartz
sleep 2
echo "Configuring xhost for localhost"
xterm -e "xhost +localhost"
sleep 2
echo "Killing any xterm sessions..."
pkill -x xterm
echo "Done"
