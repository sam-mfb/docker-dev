#!/bin/bash

# Script to fetch and update Claude agents and skills from the claude-meta repo
# Can be run during Docker build or by the user to get updated versions

set -e

CLAUDE_META_REPO="https://github.com/sam-mfb/claude-meta.git"
CLAUDE_META_DIR="$HOME/.claude-meta"
CLAUDE_DIR="$HOME/.claude"

echo "Updating Claude agents and skills from claude-meta..."

# Clone or update the claude-meta repo
if [ -d "$CLAUDE_META_DIR" ]; then
    echo "Updating existing claude-meta repo..."
    cd "$CLAUDE_META_DIR"
    git fetch origin
    git reset --hard origin/main
else
    echo "Cloning claude-meta repo..."
    git clone "$CLAUDE_META_REPO" "$CLAUDE_META_DIR"
fi

# Ensure .claude directory exists
mkdir -p "$CLAUDE_DIR"

# Copy agents if they exist in the repo
if [ -d "$CLAUDE_META_DIR/agents" ]; then
    echo "Installing agents..."
    rm -rf "$CLAUDE_DIR/agents"
    cp -r "$CLAUDE_META_DIR/agents" "$CLAUDE_DIR/agents"
fi

# Copy skills to commands (skills are slash commands)
if [ -d "$CLAUDE_META_DIR/skills" ]; then
    echo "Installing skills as commands..."
    rm -rf "$CLAUDE_DIR/commands"
    cp -r "$CLAUDE_META_DIR/skills" "$CLAUDE_DIR/commands"
fi

# Copy settings.json from general/ if it exists
if [ -f "$CLAUDE_META_DIR/general/settings.json" ]; then
    echo "Installing settings.json..."
    cp "$CLAUDE_META_DIR/general/settings.json" "$CLAUDE_DIR/settings.json"
fi

# Copy CLAUDE.md from general/ if it exists
if [ -f "$CLAUDE_META_DIR/general/CLAUDE.md" ]; then
    echo "Installing CLAUDE.md..."
    cp "$CLAUDE_META_DIR/general/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
fi

echo "Claude agents and skills updated successfully!"
echo "Source: $CLAUDE_META_REPO"
