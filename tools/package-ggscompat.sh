#!/usr/bin/env bash
#
# package-ggscompat.sh
#
# Builds a clean, deployable copy of the GaelGunStoreCompat mod in the correct
# Build 42 layout, and verifies that layout so you never ship the old flat
# structure (or a stray root mod.info) by mistake.
#
# Output:
#   dist/GaelGunStoreCompat/            (copy ready to drop into Zomboid/mods/)
#   dist/GaelGunStoreCompat-v1.2-b42.zip  (optional, with --zip)
#
# The deployable unit is ONLY mods/GaelGunStoreCompat/ -- tools/, docs/, README,
# etc. are repo scaffolding and are not part of what players install.
#
# Usage:
#   ./tools/package-ggscompat.sh           # build dist/GaelGunStoreCompat/
#   ./tools/package-ggscompat.sh --zip     # also produce the .zip
#   ./tools/package-ggscompat.sh --help

set -euo pipefail

# Resolve repo root from this script's location so it works from any cwd.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SRC="${ROOT}/mods/GaelGunStoreCompat"
DIST="${ROOT}/dist"
MODVERSION="$(grep -E '^modversion=' "${SRC}/42/mod.info" | head -1 | cut -d= -f2)"
ZIP="${DIST}/GaelGunStoreCompat-v${MODVERSION:-unknown}-b42.zip"

DO_ZIP=0
for arg in "$@"; do
    case "$arg" in
        --zip) DO_ZIP=1 ;;
        -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

fail() { echo "FAIL: $1" >&2; exit 1; }

# --- Verify the source is in the correct B42 layout BEFORE packaging ---
[ -f "${SRC}/42/mod.info" ] || fail "missing 42/mod.info"
[ -f "${SRC}/42/media/lua/client/GGSCompat_TimedActionFix.lua" ] \
    || fail "missing 42/media/lua/client/GGSCompat_TimedActionFix.lua"
[ -d "${SRC}/common" ] || fail "missing common/ folder"
[ ! -e "${SRC}/mod.info" ] || fail "stray root mod.info present (must live in 42/ only)"
[ ! -e "${SRC}/media" ] || fail "stray root media/ present (must live in 42/ only)"

# --- Build dist copy ---
rm -rf "${DIST}/GaelGunStoreCompat"
mkdir -p "${DIST}"
cp -r "${SRC}" "${DIST}/GaelGunStoreCompat"

echo "Built: ${DIST}/GaelGunStoreCompat (modversion=${MODVERSION:-unknown})"
find "${DIST}/GaelGunStoreCompat" -type f | sed "s#${ROOT}/##" | sort

if [ "${DO_ZIP}" -eq 1 ]; then
    if ! command -v zip >/dev/null 2>&1; then
        echo "WARN: 'zip' not installed; skipping archive." >&2
    else
        rm -f "${ZIP}"
        ( cd "${DIST}" && zip -rq "$(basename "${ZIP}")" GaelGunStoreCompat )
        echo "Zipped: ${ZIP}"
    fi
fi

echo "OK"
