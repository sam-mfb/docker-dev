STEP_DESC="Lean 4 through elan, with a default toolchain"
STEP_RUN_AS=user
STEP_OPTIONAL=1
STEP_REQUIRES="packages"

# elan is Lean's version manager (like rustup). Each project pins its Lean
# version in a lean-toolchain file, and elan downloads that version the first
# time the project is used. This step installs elan and a default toolchain,
# so `lake new` and loose .lean files work right away. Mathlib is not
# installed here; run `lake exe cache get` in each Mathlib project.

ELAN_BIN="$HOME/.elan/bin"

# The toolchain name elan uses: the stable channel, or a pinned release.
lean_toolchain() {
    is_latest "$LEAN_TOOLCHAIN" && echo "leanprover/lean4:stable" || echo "leanprover/lean4:v${LEAN_TOOLCHAIN#v}"
}

elan_arch() {
    case "$(uname -m)" in
        x86_64|amd64)  echo x86_64 ;;
        aarch64|arm64) echo aarch64 ;;
        *) die "unsupported CPU architecture: $(uname -m)" ;;
    esac
}

step_version() {
    [ -x "$ELAN_BIN/elan" ] || return 0
    echo "elan $("$ELAN_BIN/elan" --version 2>/dev/null | awk '{print $2}'), default $("$ELAN_BIN/elan" toolchain list 2>/dev/null | sed -n 's/ (default)$//p')"
}
step_check() {
    [ -x "$ELAN_BIN/elan" ] || return 1
    version_matches "$ELAN_VERSION" "$("$ELAN_BIN/elan" --version 2>/dev/null | awk '{print $2}')" || return 1
    # Read the toolchain list rather than run `lean`, which would download a
    # missing toolchain as a side effect.
    # With "latest", any default will do (elan may record the release that
    # stable resolved to); a pinned version must be the default.
    local list; list="$("$ELAN_BIN/elan" toolchain list 2>/dev/null)"
    if is_latest "$LEAN_TOOLCHAIN"; then
        grep -q ' (default)$' <<<"$list"
    else
        grep -qxF "$(lean_toolchain) (default)" <<<"$list"
    fi
}
step_install() {
    local v="$ELAN_VERSION"
    is_latest "$v" && v="$(github_latest_tag leanprover/elan)"
    v="${v#v}"
    local dir="$DD_RUN_DIR/elan"
    mkdir -p "$dir"
    download "https://github.com/leanprover/elan/releases/download/v$v/elan-$(elan_arch)-unknown-linux-gnu.tar.gz" "$dir/elan.tar.gz"
    tar -xzf "$dir/elan.tar.gz" -C "$dir"
    # Installs or replaces elan itself; toolchains are handled below.
    "$dir/elan-init" -y --no-modify-path --default-toolchain none

    write_env lean <<'EOT'
dd_path_prepend "$HOME/.elan/bin"
EOT
    export PATH="$ELAN_BIN:$PATH"
    elan toolchain install "$(lean_toolchain)"
    elan default "$(lean_toolchain)"
    lean --version
}
