#!/bin/bash
set -e

echo "🔧 Fixing paths for GitHub Pages..."

# Read BASE_HREF from environment or default to /
BASE_HREF="${BASE_HREF:=/}"
echo "BASE_HREF: ${BASE_HREF}"

# Normalize BASE_HREF (remove trailing slash for manipulation)
BASE_HREF="${BASE_HREF%/}"

# Find all HTML files
HTML_FILES=$(find . -name "*.html" -type f ! -path '*/.git/*' ! -path '*/.github/*')
HTML_COUNT=$(echo "$HTML_FILES" | grep -c '.' || echo 0)

if [ "$HTML_COUNT" -eq 0 ]; then
  echo "⚠️  No HTML files found, skipping path fixing"
  exit 0
fi

echo "Processing $HTML_COUNT HTML files..."
echo ""

# Counter for tracking actual replacements
TOTAL_REPLACEMENTS=0

for file in $HTML_FILES; do
  echo "  Processing: $file"
  
  # Track if file was modified
  MODIFIED=0
  
  # 1. Fix absolute URLs pointing to the original domain
  # ONLY if they exist (idempotent check)
  if grep -q 'https://www\.caterkitservices\.com/' "$file" 2>/dev/null; then
    # href="https://www.caterkitservices.com/..." → href="./..."
    COUNT=$(sed -i 's|href="https://www\.caterkitservices\.com/|href="./|g' "$file" | grep -c '^' || echo 0)
    sed -i "s|href='https://www\.caterkitservices\.com/|href='./|g" "$file"
    
    # src="https://www.caterkitservices.com/..." → src="./..."
    sed -i 's|src="https://www\.caterkitservices\.com/|src="./|g' "$file"
    sed -i "s|src='https://www\.caterkitservices\.com/|src='./|g" "$file"
    
    echo "    ✓ Fixed domain-absolute URLs"
    MODIFIED=1
    TOTAL_REPLACEMENTS=$((TOTAL_REPLACEMENTS + 1))
  fi
  
  # 2. Fix root-relative paths based on BASE_HREF
  if [ "$BASE_HREF" = "" ] || [ "$BASE_HREF" = "/" ]; then
    # ROOT DEPLOYMENT: /path → ./path
    # Only replace if NOT already relative (idempotent)
    
    # href="/path" → href="./path" (skip if already href="./")
    if grep -qE 'href="/[^/]' "$file" 2>/dev/null; then
      sed -i 's|href="/\([^/]\)|href="./\1|g' "$file"
      echo "    ✓ Fixed href=\"/path\" → href=\"./path\""
      MODIFIED=1
      TOTAL_REPLACEMENTS=$((TOTAL_REPLACEMENTS + 1))
    fi
    
    if grep -qE "href='/[^/]" "$file" 2>/dev/null; then
      sed -i "s|href='/\([^/]\)|href='./\1|g" "$file"
      MODIFIED=1
      TOTAL_REPLACEMENTS=$((TOTAL_REPLACEMENTS + 1))
    fi
    
    # src="/path" → src="./path"
    if grep -qE 'src="/[^/]' "$file" 2>/dev/null; then
      sed -i 's|src="/\([^/]\)|src="./\1|g' "$file"
      echo "    ✓ Fixed src=\"/path\" → src=\"./path\""
      MODIFIED=1
      TOTAL_REPLACEMENTS=$((TOTAL_REPLACEMENTS + 1))
    fi
    
    if grep -qE "src='/[^/]" "$file" 2>/dev/null; then
      sed -i "s|src='/\([^/]\)|src='./\1|g" "$file"
      MODIFIED=1
      TOTAL_REPLACEMENTS=$((TOTAL_REPLACEMENTS + 1))
    fi
    
    # url(/path) → url(./path)
    if grep -qE 'url\(/[^/]' "$file" 2>/dev/null; then
      sed -i 's|url(/\([^/]\)|url(./\1|g' "$file"
      sed -i "s|url('/\([^/]\)|url('./\1|g" "$file"
      sed -i 's|url("/\([^/]\)|url("./\1|g' "$file"
      echo "    ✓ Fixed url(/path) → url(./path)"
      MODIFIED=1
      TOTAL_REPLACEMENTS=$((TOTAL_REPLACEMENTS + 1))
    fi
    
  else
    # SUBPATH DEPLOYMENT: /path → /base/path
    # Critical: prevent double slashes like /archived-sites//path
    
    # href="/path" → href="/base/path" (only if not already prefixed)
    if grep -qE "href=\"/[^/]" "$file" 2>/dev/null && ! grep -q "href=\"$BASE_HREF/" "$file" 2>/dev/null; then
      # Use \1 to capture everything after the first /
      sed -i "s|href=\"/\([^/]\"|href=\"$BASE_HREF/\1\"|g" "$file"
      echo "    ✓ Prefixed href=\"/...\" with BASE_HREF"
      MODIFIED=1
      TOTAL_REPLACEMENTS=$((TOTAL_REPLACEMENTS + 1))
    fi
    
    if grep -qE "href='/[^/]" "$file" 2>/dev/null && ! grep -q "href='$BASE_HREF/" "$file" 2>/dev/null; then
      sed -i "s|href='/\([^/]'\)|href='$BASE_HREF/\1|g" "$file"
      MODIFIED=1
      TOTAL_REPLACEMENTS=$((TOTAL_REPLACEMENTS + 1))
    fi
    
    # src="/path" → src="/base/path"
    if grep -qE 'src="/[^/]' "$file" 2>/dev/null && ! grep -q "src=\"$BASE_HREF/" "$file" 2>/dev/null; then
      sed -i "s|src=\"/\([^/]\"|src=\"$BASE_HREF/\1\"|g" "$file"
      echo "    ✓ Prefixed src=\"/...\" with BASE_HREF"
      MODIFIED=1
      TOTAL_REPLACEMENTS=$((TOTAL_REPLACEMENTS + 1))
    fi
    
    if grep -qE "src='/[^/]" "$file" 2>/dev/null && ! grep -q "src='$BASE_HREF/" "$file" 2>/dev/null; then
      sed -i "s|src='/\([^/]'\)|src='$BASE_HREF/\1|g" "$file"
      MODIFIED=1
      TOTAL_REPLACEMENTS=$((TOTAL_REPLACEMENTS + 1))
    fi
    
    # url(/path) → url(/base/path)
    if grep -qE 'url\(/[^/]' "$file" 2>/dev/null && ! grep -q "url($BASE_HREF/" "$file" 2>/dev/null; then
      sed -i "s|url(/\([^/]\)|url($BASE_HREF/\1|g" "$file"
      sed -i "s|url('/\([^/]\)|url('$BASE_HREF/\1|g" "$file"
      sed -i "s|url(\"/\([^/]\)|url(\"$BASE_HREF/\1|g" "$file"
      echo "    ✓ Prefixed url(/...) with BASE_HREF"
      MODIFIED=1
      TOTAL_REPLACEMENTS=$((TOTAL_REPLACEMENTS + 1))
    fi
  fi
  
  if [ $MODIFIED -eq 0 ]; then
    echo "    → No changes needed (already correct)"
  fi
done

echo ""
echo "✅ Path fixing complete!"
echo "Total files processed: $HTML_COUNT"
echo "Total files modified: $TOTAL_REPLACEMENTS"
echo ""

if [ $TOTAL_REPLACEMENTS -eq 0 ]; then
  echo "ℹ️  No paths needed fixing (files already correct or no absolute paths found)"
else
  echo "📋 $TOTAL_REPLACEMENTS files were updated for GitHub Pages compatibility"
fi

exit 0