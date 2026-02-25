#!/bin/bash
BASE_WEB="https://kpihx-labs.github.io/presentation"
echo "🔍 Starting VERBOSE Link Audit..."
FILES=$(find . -name "*.md" ! -path "./tmp_restore/*" ! -name "_sidebar.md")
BROKEN=0

for f in $FILES; do
    echo "--- Checking File: $f ---"
    # Extract links starting with our base URL
    LINKS=$(grep -oP 'https://kpihx-labs.github.io/presentation/#/[^)]+' "$f")
    
    if [ -z "$LINKS" ]; then
        echo "  (No internal absolute links found)"
        continue
    fi

    for link in $LINKS; do
        # Docsify Web Path: https://.../#/path/to/file.md
        # Direct Web Path: https://.../path/to/file.md
        DIRECT_URL=$(echo "$link" | sed 's|/#/|/|')
        
        echo -n "  🔗 Testing: $link -> "
        
        # Check if the raw file exists on the web server
        HTTP_CODE=$(curl -s -o /dev/null -I -w "%{http_code}" "$DIRECT_URL")
        
        if [ "$HTTP_CODE" -eq "200" ]; then
            echo "✅ OK (200)"
        else
            echo "❌ FAIL ($HTTP_CODE)"
            BROKEN=$((BROKEN + 1))
        fi
    done
done

echo ""
if [ $BROKEN -eq 0 ]; then
    echo "🎉 SUCCESS: All internal web links are reachable!"
else
    echo "🚨 TOTAL BROKEN LINKS: $BROKEN"
    exit 1
fi
