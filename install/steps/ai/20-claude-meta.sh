STEP_DESC="claude-meta plugin and global Claude Code settings"
STEP_RUN_AS=user
STEP_OPTIONAL=1
STEP_REQUIRES="claude git"

step_version() {
    jq -r '.plugins["sam-meta@claude-meta"][0].version // empty' \
        "$HOME/.claude/plugins/installed_plugins.json" 2>/dev/null
}
step_check() {
    same_file "$DD_ROOT/update-claude-meta.sh" "$HOME/update-claude-meta.sh" &&
    jq -e '.enabledPlugins["sam-meta@claude-meta"] == true' "$HOME/.claude/settings.json" >/dev/null 2>&1
}
step_install() {
    is_latest "$CLAUDE_META_VERSION" || die "claude-meta only supports CLAUDE_META_VERSION=latest"
    # Kept in ~ so it can be re-run by hand to pick up upstream changes.
    place_file "$DD_ROOT/update-claude-meta.sh" "$HOME/update-claude-meta.sh" 0755
    bash "$HOME/update-claude-meta.sh"
}
