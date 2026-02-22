#!/bin/bash
# Muslinx — Patch Applier
# Applies musl compatibility patches for a given package
# Usage: apply-patches.sh <package-name>

set -euo pipefail

PACKAGE="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCHES_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")/patches"

if [ ! -d "$PATCHES_DIR" ]; then
    echo "  [!] Patches directory not found: $PATCHES_DIR"
    exit 0
fi

PATCH_COUNT=0
for patch_file in "$PATCHES_DIR"/${PACKAGE}*.patch; do
    if [ -f "$patch_file" ]; then
        echo "  [patch] Applying $(basename "$patch_file")..."
        patch -p1 < "$patch_file"
        PATCH_COUNT=$((PATCH_COUNT + 1))
    fi
done

if [ $PATCH_COUNT -eq 0 ]; then
    echo "  [info] No patches found for $PACKAGE"
else
    echo "  [✓] Applied $PATCH_COUNT patch(es) for $PACKAGE"
fi
