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

# settings.json is co-owned: claude-meta owns the hand-authored keys, but the
# CLI stores plugin and marketplace registration in this same file, under
# enabledPlugins and extraKnownMarketplaces. Overwrite the former and carry the
# latter across, or the copy silently disables every installed plugin.
PRESERVE_KEYS='{enabledPlugins, extraKnownMarketplaces}'

if [ -f "$CLAUDE_META_DIR/general/settings.json" ]; then
    echo "Installing settings.json..."
    if [ -f "$CLAUDE_DIR/settings.json" ] && command -v jq >/dev/null 2>&1; then
        jq -s ".[1] + (.[0] | $PRESERVE_KEYS | with_entries(select(.value != null)))" \
            "$CLAUDE_DIR/settings.json" "$CLAUDE_META_DIR/general/settings.json" \
            > "$CLAUDE_DIR/settings.json.tmp" \
            && mv "$CLAUDE_DIR/settings.json.tmp" "$CLAUDE_DIR/settings.json"
    else
        cp "$CLAUDE_META_DIR/general/settings.json" "$CLAUDE_DIR/settings.json"
    fi
fi

# Global memory. Unlike settings.json this is skipped when the repo's copy is
# missing or empty (-s tests both), so an unused placeholder can't blank an
# existing ~/.claude/CLAUDE.md. The tradeoff: deleting it upstream will not
# uninstall a copy already in place — remove that by hand.
if [ -s "$CLAUDE_META_DIR/general/CLAUDE.md" ]; then
    echo "Installing CLAUDE.md..."
    cp "$CLAUDE_META_DIR/general/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
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

# Decide add-vs-update from the marketplace declaration in settings.json rather
# than from `marketplace list`, which also reports marketplaces known only from
# the ~/.claude/plugins cache. Taking the update path off a cache hit leaves
# extraKnownMarketplaces undeclared.
if jq -e --arg n "$MARKETPLACE_NAME" '.extraKnownMarketplaces[$n]' \
        "$CLAUDE_DIR/settings.json" >/dev/null 2>&1; then
    echo "Updating marketplace $MARKETPLACE_NAME..."
    claude plugin marketplace update "$MARKETPLACE_NAME"
else
    echo "Adding marketplace $MARKETPLACE_REPO..."
    claude plugin marketplace add "$MARKETPLACE_REPO" --scope user
fi

# `plugin update` needs the fully qualified name@marketplace form; the bare
# plugin name fails with "not found" even when the plugin is installed. The
# install fallback covers the not-yet-installed case and is itself idempotent.
echo "Updating plugin ${PLUGIN_NAME}@${MARKETPLACE_NAME}..."
if ! claude plugin update "${PLUGIN_NAME}@${MARKETPLACE_NAME}"; then
    echo "Not installed; installing..."
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
