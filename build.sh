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

# Add Base.lua (skip first 3 lines entirely)
awk 'NR > 3 { print $0 }' "$BASE" >> "$OUT"

# Add features
for f in "$FEATURES_DIR"/*.lua; do
    echo -e "\n\n" >> "$OUT"
    awk '
        BEGIN { header_lines=0 }
        {
            if (header_lines < 3) {
                if ($0 ~ /Copyright WirtsLegs/) {
                    # skip copyright notice
                } else {
                    if (header_lines == 0) {
                        sub(/\.lua/, "", $0)
                    }
                    print $0
                }
                header_lines++
            } else {
                print $0
            }
        }
    ' "$f" >> "$OUT"
done

echo "Build complete: $OUT"