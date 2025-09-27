#!/bin/bash
set -e

OUT="WirtsTools.lua"
BASE="Base.lua"
FEATURES_DIR="Features"
VERSION_FILE="VERSION"

VERSION=$(<"$VERSION_FILE")

# Write header
cat <<EOF > "$OUT"
---------------------------------------------------------------------
--WirtsTools.lua
--version $VERSION
--Required Notice: Copyright WirtsLegs 2024, (https://github.com/WirtsLegs/WirtsTools)
--Directions: load this script as Do Script File, then call setup functions in a do script action for the features you wish to use
--See readme for full details
---------------------------------------------------------------------
EOF

# Add Base.lua
cat "$BASE" >> "$OUT"

# Add features
for f in "$FEATURES_DIR"/*.lua; do
    echo -e "\n\n" >> "$OUT"
    awk '
        BEGIN { header_done=0 }
        /^--.*\.lua$/ {
            # Strip .lua from header
            sub(/\.lua/, "", $0)
            print $0
            next
        }
        /--Required Notice: Copyright WirtsLegs 2024, \(https:\/\/github.com\/WirtsLegs\/WirtsTools\)/ { next }
        { print $0 }
    ' "$f" >> "$OUT"
done

echo "Build complete: $OUT"