#!/usr/bin/env bash
# security_keyword_scan.sh
#
# Prioritized, categorized keyword sweep for security-sensitive code.
# This is a TRIAGE tool, not a vulnerability scanner: every hit needs to be
# read in full before it means anything. See methodology/02-static-analysis.md.
#
# Usage: ./security_keyword_scan.sh <path-to-repo> [extensions...]
#   e.g. ./security_keyword_scan.sh . rs c h

set -euo pipefail

REPO="${1:-.}"
shift || true
EXTS=("$@")
if [ ${#EXTS[@]} -eq 0 ]; then
    EXTS=(rs c h)
fi

INCLUDE_ARGS=()
for ext in "${EXTS[@]}"; do
    INCLUDE_ARGS+=(--include="*.${ext}")
done

cd "$REPO"

declare -A CATEGORIES=(
    ["1-auth-and-crypto"]="verify|authenticate|authoriz|signature|attest|nonce|challenge|hmac"
    ["2-trust-and-update-chain"]="boot|manifest|rollback|update|firmware|capability"
    ["3-memory-and-parsing"]="unsafe|deserialize|decode|memcpy|sizeof\(.*\*"
    ["4-ipc-and-messaging"]="ipc|dispatch|handler|callback.*msg"
)

for category in "${!CATEGORIES[@]}"; do
    pattern="${CATEGORIES[$category]}"
    echo "=================================================================="
    echo " Category: $category"
    echo " Pattern:  $pattern"
    echo "=================================================================="
    grep -rEl "$pattern" "${INCLUDE_ARGS[@]}" . 2>/dev/null | sort || echo "  (no matches)"
    echo
done

echo "=================================================================="
echo " Reminder: every file above needs full-function reading, not just"
echo " the matched line. See methodology/02-static-analysis.md."
echo "=================================================================="
