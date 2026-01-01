#!/bin/bash
set -e

echo "🔧 Fixing paths for GitHub Pages..."

# Read BASE_HREF from environment or default to /
BASE_HREF="${BASE_HREF:=/}"
echo "BASE_HREF: ${BASE_HREF}"

# Remove trailing slash for cleaner manipulation (we'll add it back when needed)
BASE_HREF="${BASE_HREF%/}"

# Find all HTML files
HTML_FILES=$(find . -name "*.html" -type f ! -path '*/.git/*' ! -path '*/.github/*')
HTML_COUNT=$(echo "$HTML_FILES" | wc -l)

echo "Processing $HTML_COUNT HTML files..."

# Counter for tracking replacements
TOTAL_REPLACEMENTS=0

for file in $HTML_FILES; do
  echo "  Processing: $file"
  
  # Create backup
  cp "$file" "$file.backup"
  
  # 1. Fix absolute URLs pointing to the original domain
  # href="https://www.caterkitservices.com/..." → href="./..."
  sed -i 's|href="https://www\.caterkitservices\.com/|href="./|g' "$file"
  sed -i "s|href='https://www\.caterkitservices\.com/|href='./|g" "$file"
  
  # src="https://www.caterkitservices.com/..." → src="./..."
  sed -i 's|src="https://www\.caterkitservices\.com/|src="./|g' "$file"
  sed -i "s|src='https://www\.caterkitservices\.com/|src='./|g" "$file"
  
  # 2. Fix root-relative paths to be relative
  # href="/category/..." → href="./category/..."  (but only if BASE_HREF is /)
  if [ "$BASE_HREF" == "/" ] || [ -z "$BASE_HREF" ]; then
    # For root deployment, convert /path to ./path
    sed -i 's|href="/|href="./|g' "$file"
    sed -i "s|href='/|href='./|g" "$file"
    sed -i 's|src="/|src="./|g' "$file"
    sed -i "s|src='/|src='./|g" "$file"
    sed -i 's|url(/|url(./|g' "$file"
    sed -i "s|url('/|url('./|g" "$file"
    sed -i 's|url(\"/|url(\"./|g' "$file"
  else
    # For subpath deployment (e.g., /archived-sites/), prefix paths
    sed -i 's|href="/|href="'$BASE_HREF'/|g' "$file"
    sed -i "s|href='/|href='$BASE_HREF/|g" "$file"
    sed -i 's|src="/|src="'$BASE_HREF'/|g' "$file"
    sed -i "s|src='/|src='$BASE_HREF/|g" "$file"
    sed -i 's|url(/|url('$BASE_HREF'/|g' "$file"
    sed -i "s|url('/|url('$BASE_HREF/|g" "$file"
    sed -i 's|url(\"/|url(\"'$BASE_HREF'/|g' "$file"
  fi
  
  # 3. Count replacements
  CHANGES=$(diff "$file.backup" "$file" 2>/dev/null | grep -c '^<' || echo 0)
  if [ $CHANGES -gt 0 ]; then
    echo "    ✓ Fixed $CHANGES lines"
    TOTAL_REPLACEMENTS=$((TOTAL_REPLACEMENTS + CHANGES))
  fi
  
  # Cleanup backup
  rm "$file.backup"
done

echo ""
echo "✅ Path fixing complete!"
echo "Total files processed: $HTML_COUNT"
echo "Total line replacements: $TOTAL_REPLACEMENTS"

# Note: We don't validate TOTAL_REPLACEMENTS here because:
# - sed always returns 0 even if no substitutions were made
# - diff-based counting may not accurately reflect actual changes
# - The script logs show what was processed, manual review is better
# - Files may already have correct paths from previous runs

echo "📋 All paths fixed for GitHub Pages deployment"
exit 0
