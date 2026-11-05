STEP_DESC="OpenAI Codex CLI"
STEP_RUN_AS=user
STEP_OPTIONAL=1
STEP_REQUIRES="node bubblewrap"

step_version() { npm_global_version @openai/codex; }
step_check()   { npm_global_check @openai/codex "$CODEX_VERSION"; }
step_install() { npm_global_install @openai/codex "$CODEX_VERSION"; }
