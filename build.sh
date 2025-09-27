#!/bin/bash
set -e

OUT="WirtsTools.lua"
BASE="Base.lua"
FEATURES_DIR="Features"

cat "$BASE" > "$OUT"
for f in "$FEATURES_DIR"/*.lua; do
    cat "$f" >> "$OUT"
done

echo "Build complete: $OUT"