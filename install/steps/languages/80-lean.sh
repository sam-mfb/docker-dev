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

# The toolchain name for a Lean version, as elan writes it.
toolchain_name() { echo "leanprover/lean4:v${1#v}"; }

# The default toolchain, as recorded in elan's settings. (`elan show` words
# this differently depending on what is installed, and `elan toolchain list`
# does not mark it.)
default_toolchain() {
    sed -n 's/^default_toolchain *= *"\(.*\)"$/\1/p' "$HOME/.elan/settings.toml" 2>/dev/null
}

# installed NAME -- the toolchain's folder exists. elan names it after the
# toolchain with / as -- and : as --- (leanprover--lean4---v4.36.0).
installed() {
    local dir="${1//\//--}"
    [ -n "$1" ] && [ -d "$HOME/.elan/toolchains/${dir//:/---}" ]
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
    echo "elan $("$ELAN_BIN/elan" --version 2>/dev/null | awk '{print $2}'), default $(default_toolchain)"
}
step_check() {
    [ -x "$ELAN_BIN/elan" ] || return 1
    version_matches "$ELAN_VERSION" "$("$ELAN_BIN/elan" --version 2>/dev/null | awk '{print $2}')" || return 1
    local def; def="$(default_toolchain)"
    installed "$def" || return 1
    # With "latest", any release as default will do; it is left alone until
    # --force, like every other "latest" pin.
    if is_latest "$LEAN_TOOLCHAIN"; then
        [[ "$def" == leanprover/lean4:v* ]]
    else
        [ "$def" = "$(toolchain_name "$LEAN_TOOLCHAIN")" ]
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
    # An exact release rather than the "stable" channel: a channel default
    # makes elan look up the current release online when lean runs.
    local lean_v="$LEAN_TOOLCHAIN"
    is_latest "$lean_v" && lean_v="$(github_latest_tag leanprover/lean4)"
    elan toolchain install "$(toolchain_name "$lean_v")"
    elan default "$(toolchain_name "$lean_v")"
    lean --version
}
