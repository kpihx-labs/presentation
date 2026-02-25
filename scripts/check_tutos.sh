#!/bin/bash
# scripts/check_tutos.sh
# Verifies that every tutorial in tutos_live/ is referenced:
# 1. In at least one presentation .md file (Pillars).
# 2. Specifically in EVOLUTION.md (Journal).
# FULL VERBOSE MODE

cd "$(dirname "$0")/.." || exit 1

TUTOS_DIR="tutos_live"
PRESENTATION_MD_FILES=$(find . -maxdepth 1 -name "*.md")
EVOLUTION_FILE="EVOLUTION.md"

BROKEN=0
echo "-------------------------------------------------------"
echo "🔍 Starting Full Verbose Tutorial Reference Audit..."
echo "📂 Scanning tutorials in: $TUTOS_DIR"
echo "-------------------------------------------------------"

for tuto in $(find "$TUTOS_DIR" -name "*.md" ! -name "README.md"); do
    BN=$(basename "$tuto")
    echo "📘 Auditing tutorial: $BN"
    
    # 1. Check in any pillar
    FOUND_ANY=0
    for md_file in $PRESENTATION_MD_FILES; do
        if grep -q "$BN" "$md_file"; then
            FOUND_ANY=1
            break
        fi
    done
    
    if [ "$FOUND_ANY" -eq 1 ]; then
        echo "  ✅ Linked in Pillars."
    else
        echo "  ❌ ERROR: Tutorial $BN is NOT referenced in any root pillar!"
        BROKEN=$((BROKEN + 1))
    fi

    # 2. Check specifically in EVOLUTION.md
    if grep -q "$BN" "$EVOLUTION_FILE"; then
        echo "  ✅ Present in EVOLUTION.md"
    else
        echo "  ❌ ERROR: Tutorial $BN is MISSING from the Journal (EVOLUTION.md)!"
        BROKEN=$((BROKEN + 1))
    fi
done

echo "-------------------------------------------------------"
if [ "$BROKEN" -eq 0 ]; then
    echo "🎉 SUCCESS: All tutorials are properly linked and journaled!"
else
    echo "🚨 FAILURE: $BROKEN reference errors found!"
    exit 1
fi
echo "-------------------------------------------------------"
