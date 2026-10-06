#!/usr/bin/env bash
# repo_structure_map.sh
#
# Maps the crate/workspace/build structure of a repository (Rust and/or C/CMake)
# as the first step of a security audit. Run this before reading any code.
#
# Usage: ./repo_structure_map.sh <path-to-repo>

set -euo pipefail

REPO="${1:-.}"
cd "$REPO"

echo "=================================================================="
echo " Repository structure map: $(pwd)"
echo "=================================================================="

echo
echo "--- Rust build manifests ---"
find . -name "Cargo.toml" -not -path "*/target/*" | while read -r f; do
    echo "### $f"
    cat "$f"
    echo
done

echo
echo "--- C/CMake build files ---"
find . -iname "CMakeLists.txt" -not -path "*/build/*" | sort

echo
echo "--- Source file counts by extension ---"
find . -type f ! -path "*/.git/*" ! -path "*/target/*" ! -path "*/build/*" \
    | sed 's/.*\.//' | sort | uniq -c | sort -rn | head -20

echo
echo "--- Unsafe/FFI surface (Rust) ---"
# NOTE: every grep below is wrapped with `|| true` (or an explicit
# fallback). Under `set -euo pipefail`, a grep that finds zero matches
# exits 1, and pipefail propagates that non-zero status through the rest
# of the pipeline even when later stages (wc -l, xargs, etc.) succeed --
# which would silently kill this script mid-scan on a clean/safe repo
# with no error message at all. Zero matches is a legitimate, expected
# result here, not a failure.
UNSAFE_COUNT=$( { grep -rln "unsafe" --include="*.rs" . 2>/dev/null || true; } | wc -l)
echo "Files containing 'unsafe': $UNSAFE_COUNT"
grep -rln 'extern "C"\|#\[no_mangle\]' --include="*.rs" . 2>/dev/null || echo "(none found)"

echo
echo "--- Unsafe/FFI surface (C) ---"
{ grep -rln "memcpy\|memmove\|strcpy\|sprintf" --include="*.c" . 2>/dev/null || true; } | wc -l | \
    xargs echo "Files using raw memory/string functions:"

echo
echo "=================================================================="
echo " Done. Next: build the cross-repo dependency table (see methodology/01-recon-and-mapping.md)."
echo "=================================================================="
