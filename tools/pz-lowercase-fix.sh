#!/usr/bin/env bash
#
# pz-lowercase-fix.sh
#
# Project Zomboid on Linux is case-sensitive about asset paths; Windows is not.
# A mod that ships a file as "Foo.png" but references it as "foo.png" loads fine on
# a Windows client but fails on a Linux/Ubuntu server with missing icons, pink/black
# textures, missing sounds, or "file not found" spam.
#
# This helper scans a mod directory and creates LOWERCASE SYMLINK ALIASES for any
# file or directory whose name contains uppercase letters, so that lowercased
# references resolve. It does NOT rename or delete anything (update-safe against
# Steam Workshop re-downloads). It is idempotent and runs as a dry-run unless you
# pass --apply.
#
# DIRECTION / LIMITATION: this only fixes the case where the REAL name contains
# uppercase and the mod REFERENCES it in lowercase (real "AnimSets" -> ref
# "animsets"). The reverse (real name already lowercase, reference uses uppercase:
# real "animsets" -> ref "AnimSets") is NOT detected by this scan, because the scan
# cannot know which uppercased spelling a script expects. For that direction, derive
# the exact missing paths from the server log and create those aliases specifically.
#
# Typical targets on the GCP Ubuntu 24.04 server:
#   ~/Zomboid/Workshop/<id>
#   ~/.steam/steamapps/workshop/content/108600/<id>
#   /serverfiles/steamapps/workshop/content/108600/<id>
#
# Usage:
#   ./pz-lowercase-fix.sh <mod-or-workshop-dir>            # dry-run (report only)
#   ./pz-lowercase-fix.sh --apply <mod-or-workshop-dir>    # create the symlinks
#   ./pz-lowercase-fix.sh --help
#
# Notes:
#   * Only names containing uppercase letters are aliased; all-lowercase names are
#     already reachable and skipped.
#   * If a lowercase entry already exists as a real file/dir, it is left untouched
#     and reported as a conflict (never overwritten).
#   * Re-running after a Workshop update is safe; existing correct symlinks are kept.

set -euo pipefail

APPLY=0
TARGET=""

usage() {
    sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --apply) APPLY=1; shift ;;
        -h|--help) usage 0 ;;
        --) shift; break ;;
        -*) echo "Unknown option: $1" >&2; usage 1 ;;
        *) TARGET="$1"; shift ;;
    esac
done

if [ -z "${TARGET}" ]; then
    echo "Error: no target directory given." >&2
    usage 1
fi

if [ ! -d "${TARGET}" ]; then
    echo "Error: '${TARGET}' is not a directory." >&2
    exit 1
fi

created=0
skipped_lower=0
conflicts=0

if [ "${APPLY}" -eq 0 ]; then
    echo "== DRY RUN ==  (pass --apply to create symlinks)"
fi
echo "Scanning: ${TARGET}"
echo

# Process deepest paths first so that directory aliases do not shift entries
# while we are still walking into them.
while IFS= read -r -d '' entry; do
    name="$(basename "${entry}")"
    dir="$(dirname "${entry}")"
    lower="$(printf '%s' "${name}" | tr '[:upper:]' '[:lower:]')"

    # Already lowercase: reachable as-is.
    if [ "${name}" = "${lower}" ]; then
        skipped_lower=$((skipped_lower + 1))
        continue
    fi

    aliaspath="${dir}/${lower}"

    # A correct symlink already exists -> idempotent skip.
    if [ -L "${aliaspath}" ]; then
        continue
    fi

    # A real file/dir already occupies the lowercase name -> do not touch it.
    if [ -e "${aliaspath}" ]; then
        echo "CONFLICT: ${aliaspath} already exists as a real entry; skipping alias for ${name}"
        conflicts=$((conflicts + 1))
        continue
    fi

    if [ "${APPLY}" -eq 1 ]; then
        ln -s "${name}" "${aliaspath}"
        echo "linked:  ${lower} -> ${name}   (in ${dir})"
    else
        echo "would link: ${lower} -> ${name}   (in ${dir})"
    fi
    created=$((created + 1))
done < <(find "${TARGET}" -depth \( -type f -o -type d \) -print0)

echo
echo "Summary:"
echo "  aliases $([ "${APPLY}" -eq 1 ] && echo created || echo needed): ${created}"
echo "  already lowercase (skipped):              ${skipped_lower}"
echo "  conflicts (real entry already lowercase): ${conflicts}"
if [ "${APPLY}" -eq 0 ] && [ "${created}" -gt 0 ]; then
    echo
    echo "Re-run with --apply to create the ${created} symlink alias(es)."
fi
