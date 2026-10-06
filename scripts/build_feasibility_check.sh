#!/usr/bin/env bash
# build_feasibility_check.sh
#
# Pre-flight check: before committing time/memory to a full build of a
# target repository, verify whether its key system/vendor dependencies are
# even present. Saves time on heavy native builds (embedded toolchains,
# large C++ dependency trees, vendor SDKs) that are doomed to fail for
# reasons unrelated to the code itself.
#
# Usage: ./build_feasibility_check.sh <pkg-config-name> [<pkg-config-name> ...]

set -uo pipefail

echo "=================================================================="
echo " Build feasibility pre-flight check"
echo "=================================================================="

echo
echo "--- System memory ---"
free -h

echo
echo "--- Requested pkg-config dependencies ---"
if [ "$#" -eq 0 ]; then
    echo "  (no package names given; pass pkg-config names as arguments)"
else
    for pkg in "$@"; do
        if pkg-config --exists "$pkg" 2>/dev/null; then
            echo "  [OK]      $pkg  ($(pkg-config --modversion "$pkg" 2>/dev/null))"
        else
            echo "  [MISSING] $pkg"
        fi
    done
fi

echo
echo "--- Common toolchain presence ---"
for tool in gcc clang arm-none-eabi-gcc cargo rustc west; do
    if command -v "$tool" >/dev/null 2>&1; then
        echo "  [OK]      $tool  ($(command -v "$tool"))"
    else
        echo "  [MISSING] $tool"
    fi
done

cat <<'EOF'

--- Isolated crate build-script probe (Rust only) ---
If a specific crate's build.rs is suspected to require a vendor SDK
(e.g. hardware client libraries), isolate it in a throwaway project
before attempting the full workspace build:

    mkdir -p /tmp/probe/src && cd /tmp/probe
    cat > Cargo.toml <<CARGOEOF
    [package]
    name = "probe"
    version = "0.1.0"
    edition = "2021"
    [dependencies]
    <suspect-crate> = "*"
    CARGOEOF
    echo 'fn main() {}' > src/main.rs
    cargo build 2>&1 | tail -40

Read the actual build-script panic/error message — it usually names the
exact missing environment variable or SDK path directly, which is far
faster than debugging a full workspace build failure.
EOF
