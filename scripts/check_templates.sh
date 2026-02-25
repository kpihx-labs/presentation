#!/bin/bash
# scripts/check_templates.sh
# Verifies that every template in tutos_live/templates is referenced in at least one .md file.
# FULL VERBOSE MODE

cd "$(dirname "$0")/.." || exit 1

TEMPLATES_DIR="tutos_live/templates"
ALL_MD_FILES=$(find . -name "*.md" ! -path "*/tmp*")

BROKEN=0
echo "-------------------------------------------------------"
echo "🔍 Starting Full Verbose Template Reference Audit..."
echo "📂 Scanning directory: $TEMPLATES_DIR"
echo "-------------------------------------------------------"

for template in $(ls "$TEMPLATES_DIR"); do
    echo "📄 Checking template: $template"
    FOUND=0
    for md_file in $ALL_MD_FILES; do
        if grep -q "$template" "$md_file"; then
            OCCURRENCES=$(grep -c "$template" "$md_file")
            echo "  ✅ Found in: $md_file ($OCCURRENCES match(es))"
            FOUND=1
        fi
    done
    
    if [ "$FOUND" -eq 0 ]; then
        echo "  ❌ ERROR: No reference found for $template in any Markdown file!"
        BROKEN=$((BROKEN + 1))
    fi
done

echo "-------------------------------------------------------"
if [ "$BROKEN" -eq 0 ]; then
    echo "🎉 SUCCESS: All templates are properly referenced!"
else
    echo "🚨 FAILURE: $BROKEN templates are missing references!"
    exit 1
fi
echo "-------------------------------------------------------"
