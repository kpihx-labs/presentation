#!/bin/bash
# scripts/check_tutos.sh
# Verifies that every tutorial in tutos_live/ is referenced in at least one presentation .md file.
# FULL VERBOSE MODE

cd "$(dirname "$0")/.." || exit 1

TUTOS_DIR="tutos_live"
PRESENTATION_MD_FILES=$(find . -maxdepth 1 -name "*.md")

BROKEN=0
echo "-------------------------------------------------------"
echo "🔍 Starting Full Verbose Tutorial Reference Audit..."
echo "📂 Scanning tutorials in: $TUTOS_DIR"
echo "-------------------------------------------------------"

# Find all md files in tutos_live and its subdirectories, excluding the root README.md
for tuto in $(find "$TUTOS_DIR" -name "*.md" ! -name "README.md"); do
    BN=$(basename "$tuto")
    echo "📘 Checking tutorial file: $BN"
    FOUND=0
    
    for md_file in $PRESENTATION_MD_FILES; do
        if grep -q "$BN" "$md_file"; then
            OCCURRENCES=$(grep -c "$BN" "$md_file")
            echo "  ✅ Referenced in pillar: $md_file ($OCCURRENCES match(es))"
            FOUND=1
        fi
    done
    
    if [ "$FOUND" -eq 0 ]; then
        echo "  ❌ ERROR: Tutorial $BN is NOT referenced in any root presentation file!"
        BROKEN=$((BROKEN + 1))
    fi
done

echo "-------------------------------------------------------"
if [ "$BROKEN" -eq 0 ]; then
    echo "🎉 SUCCESS: All tutorials are properly linked from main pillars!"
else
    echo "🚨 FAILURE: $BROKEN tutorials are missing references!"
    exit 1
fi
echo "-------------------------------------------------------"
