STEP_DESC="Azure DevOps extension for the Azure CLI"
STEP_RUN_AS=user
STEP_OPTIONAL=1
STEP_REQUIRES="az"

step_version() { az extension show --name azure-devops --query version -o tsv 2>/dev/null; }
step_check() {
    local v; v="$(step_version)"
    [ -n "$v" ] && version_matches "$AZ_DEVOPS_VERSION" "$v"
}
step_install() {
    local args=(--name azure-devops --upgrade --yes)
    is_latest "$AZ_DEVOPS_VERSION" || args=(--name azure-devops --version "$AZ_DEVOPS_VERSION" --yes)
    az extension remove --name azure-devops >/dev/null 2>&1 || true
    az extension add "${args[@]}"
}
