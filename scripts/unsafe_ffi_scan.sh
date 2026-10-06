#!/usr/bin/env bash
# unsafe_ffi_scan.sh
#
# Enumerates unsafe blocks and FFI boundaries in a Rust codebase, and the
# raw memory/string-function surface in C, with surrounding context for
# faster triage.
#
# Usage: ./unsafe_ffi_scan.sh <path-to-repo>

set -euo pipefail

REPO="${1:-.}"
cd "$REPO"

echo "=================================================================="
echo " Rust: unsafe blocks (with 2 lines of context)"
echo "=================================================================="
grep -rn -B2 -A2 "unsafe" --include="*.rs" . 2>/dev/null | grep -v "^--$" || echo "  (none found)"

echo
echo "=================================================================="
echo " Rust: FFI declarations"
echo "=================================================================="
grep -rn 'extern "C"\|#\[no_mangle\]' --include="*.rs" . 2>/dev/null || echo "  (none found)"

echo
echo "=================================================================="
echo " C: raw memory/string functions (common overflow/misuse sources)"
echo "=================================================================="
grep -rn "memcpy\|memmove\|strcpy\|strcat\|sprintf\b" --include="*.c" --include="*.h" . 2>/dev/null || echo "  (none found)"

echo
echo "=================================================================="
echo " C: sizeof() applied to a pointer-typed expression (common bug class:"
echo " sizeof(ptr) instead of sizeof(*ptr) or a fixed constant)"
echo "=================================================================="
# Heuristic only — always verify manually. Looks for sizeof(x) where x is a
# single identifier; cross-reference against that identifier's declared type.
grep -rn "sizeof([a-zA-Z_][a-zA-Z0-9_]*)" --include="*.c" . 2>/dev/null || echo "  (no simple candidates found)"
echo
echo "  NOTE: the sizeof() heuristic above is a starting point only. For each"
echo "  hit, manually confirm the identifier's declared type — this pattern"
echo "  is correct when the identifier is a value, and a bug when it is a"
echo "  pointer but a single element's size was intended."
