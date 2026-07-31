#!/bin/bash

# Installs/updates the claude-meta plugin (skills + agents) and the global
# Claude Code settings it ships. Run during Docker build or by hand at any time
# to pick up upstream changes.
#
# Skills and agents come from the claude-meta marketplace via `claude plugin`,
# which handles versioning and directory layout. Only ~/.claude/settings.json is
# copied by hand, since a plugin cannot write user-level settings.
#
# Restart Claude Code after running this for plugin changes to take effect.

set -euo pipefail

MARKETPLACE_REPO="sam-mfb/claude-meta"
MARKETPLACE_NAME="claude-meta"
PLUGIN_NAME="sam-meta"
CLAUDE_DIR="$HOME/.claude"
CLAUDE_META_DIR="$HOME/.claude-meta"

echo "Updating Claude plugin and settings from claude-meta..."

mkdir -p "$CLAUDE_DIR"

# --- Global settings ---------------------------------------------------------
#
# Done before the plugin commands so a fresh container has settings and the
# onboarding flags in place before the CLI is invoked.
#
# settings.json is overwritten, not merged: the repo is the source of truth, so
# keys removed upstream need to disappear here too. Anything you want kept
# belongs in claude-meta's general/settings.json.

# A shallow clone is the cheapest way to read general/ without depending on the
# marketplace's internal checkout layout.
if [ -d "$CLAUDE_META_DIR/.git" ]; then
    echo "Refreshing claude-meta clone..."
    git -C "$CLAUDE_META_DIR" fetch --depth 1 origin main
    git -C "$CLAUDE_META_DIR" reset --hard FETCH_HEAD
else
    echo "Cloning claude-meta..."
    rm -rf "$CLAUDE_META_DIR"
    git clone --depth 1 "https://github.com/${MARKETPLACE_REPO}.git" "$CLAUDE_META_DIR"
fi

if [ -f "$CLAUDE_META_DIR/general/settings.json" ]; then
    echo "Installing settings.json..."
    cp "$CLAUDE_META_DIR/general/settings.json" "$CLAUDE_DIR/settings.json"
fi

# Skip the first-run wizard in a fresh container. ~/.claude.json also holds
# auth, per-project history, and caches, so merge these two keys rather than
# replacing the file.
if command -v jq >/dev/null 2>&1; then
    echo "Marking onboarding complete..."
    [ -f "$HOME/.claude.json" ] || echo '{}' > "$HOME/.claude.json"
    jq '. + {hasCompletedOnboarding: true, tipsHistory: ({"new-user-warmup": 1} + (.tipsHistory // {}))}' \
        "$HOME/.claude.json" > "$HOME/.claude.json.tmp" \
        && mv "$HOME/.claude.json.tmp" "$HOME/.claude.json"
else
    echo "jq not found; skipping onboarding flags." >&2
fi

# --- Plugin (skills + agents) ------------------------------------------------

if claude plugin marketplace list 2>/dev/null | grep -q "$MARKETPLACE_NAME"; then
    echo "Updating marketplace $MARKETPLACE_NAME..."
    claude plugin marketplace update "$MARKETPLACE_NAME"
else
    echo "Adding marketplace $MARKETPLACE_REPO..."
    claude plugin marketplace add "$MARKETPLACE_REPO" --scope user
fi

if claude plugin list 2>/dev/null | grep -q "$PLUGIN_NAME"; then
    echo "Updating plugin $PLUGIN_NAME..."
    claude plugin update "$PLUGIN_NAME"
else
    echo "Installing plugin $PLUGIN_NAME..."
    claude plugin install "${PLUGIN_NAME}@${MARKETPLACE_NAME}" --scope user
fi

# --- Legacy cleanup ----------------------------------------------------------
#
# Earlier versions of this script copied skills into ~/.claude/commands/ and
# agents into ~/.claude/agents/. The plugin now provides both; remove only the
# specific paths this script used to create so they don't load twice.

for legacy in "$CLAUDE_DIR/commands/codex-cli" "$CLAUDE_DIR/commands/gemini-cli" \
              "$CLAUDE_DIR/agents/research-investigator.md" \
              "$CLAUDE_DIR/agents/test-quality-reviewer.md"; do
    if [ -e "$legacy" ]; then
        echo "Removing legacy install: $legacy"
        rm -rf "$legacy"
    fi
done

echo "Done. Source: https://github.com/${MARKETPLACE_REPO}"
echo "Restart Claude Code to load plugin changes."
