#!/bin/bash
# scripts/check_links.sh
# Verifies that all absolute internal links point to an existing file locally.
# FULL VERBOSE MODE

cd "$(dirname "$0")/.." || exit 1

echo "-------------------------------------------------------"
echo "🔍 Starting Full Verbose Logical Link Audit..."
echo "-------------------------------------------------------"

FILES=$(find . -name "*.md" ! -path "*/tmp*" ! -name "_sidebar.md")
BROKEN=0

for f in $FILES; do
    echo "📄 Scanning file: $f"
    # Extract internal absolute links
    LINKS=$(grep -oP 'https://kpihx-labs.github.io/presentation/#/[^)]+' "$f")
    
    if [ -z "$LINKS" ]; then
        echo "  (No internal absolute links found)"
        continue
    fi

    for link in $LINKS; do
        # Extract file path from link
        FILE_PATH=$(echo "$link" | sed 's|https://kpihx-labs.github.io/presentation/#/||')
        
        echo -n "  🔗 Testing link: $link -> "
        if [ -f "$FILE_PATH" ]; then
            echo "✅ OK (File exists: $FILE_PATH)"
        else
            echo "❌ BROKEN (File NOT found: $FILE_PATH)"
            BROKEN=$((BROKEN + 1))
        fi
    done
done

echo "-------------------------------------------------------"
if [ "$BROKEN" -eq 0 ]; then
    echo "🎉 SUCCESS: All internal absolute links are logically sound!"
else
    echo "🚨 FAILURE: Found $BROKEN broken internal links!"
    exit 1
fi
echo "-------------------------------------------------------"
