#!/bin/bash

# Check if ANTHROPIC_API_KEY is set
if [ -z "$ANTHROPIC_API_KEY" ]; then
  echo "Error: ANTHROPIC_API_KEY environment variable is not set"
  exit 0
fi

# Check if ~/.claude.json exists
if [ ! -f ~/.claude.json ]; then
  echo "Error: ~/.claude.json file not found"
  exit 1
fi

# Replace [ANTHROPIC_API_KEY] with the value from the environment variable
sed -i "s/\[ANTHROPIC_API_KEY\]/$ANTHROPIC_API_KEY/g" ~/.claude.json

echo "Successfully updated API key in ~/.claude.json"
