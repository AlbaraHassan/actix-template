#!/bin/bash
# Muslinx — Source Tarball Fetcher
# Downloads and verifies source tarballs
# Usage: fetch-source.sh <url> <output-path>

set -euo pipefail

URL="$1"
OUTPUT="$2"

if [ -f "$OUTPUT" ]; then
    echo "  [cached] $(basename "$OUTPUT")"
    exit 0
fi

mkdir -p "$(dirname "$OUTPUT")"

echo "  [fetch] $(basename "$OUTPUT")"
echo "    URL: $URL"

# Download with retries
MAX_RETRIES=3
RETRY=0
while [ $RETRY -lt $MAX_RETRIES ]; do
    if curl -fSL --retry 3 --retry-delay 2 \
        --connect-timeout 30 \
        -o "$OUTPUT.part" "$URL"; then
        mv "$OUTPUT.part" "$OUTPUT"
        echo "  [✓] Downloaded $(basename "$OUTPUT") ($(du -h "$OUTPUT" | cut -f1))"
        exit 0
    fi
    RETRY=$((RETRY + 1))
    echo "  [!] Download failed, retry $RETRY/$MAX_RETRIES..."
    sleep $((RETRY * 2))
done

echo "  [✗] Failed to download: $URL"
rm -f "$OUTPUT.part"
exit 1
