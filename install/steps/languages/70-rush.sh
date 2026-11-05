STEP_DESC="Rush, the monorepo build tool"
STEP_RUN_AS=user
STEP_OPTIONAL=1
STEP_REQUIRES="node"

step_version() { npm_global_version @microsoft/rush; }
step_check()   { npm_global_check @microsoft/rush "$RUSH_VERSION"; }
step_install() { npm_global_install @microsoft/rush "$RUSH_VERSION"; }
