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
    sed -i 's|href="https://www\.caterkitservices\.com/|href="./|g' "$file"
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
      sed -i 's|href="/\([^"]*\)"|href="./\1"|g' "$file"
      echo "    ✓ Fixed href=\"/path\" → href=\"./path\""
      MODIFIED=1
      TOTAL_REPLACEMENTS=$((TOTAL_REPLACEMENTS + 1))
    fi
    
    if grep -qE "href='/[^/]" "$file" 2>/dev/null; then
      sed -i "s|href='/\([^']*\)'|href='./\1'|g" "$file"
      MODIFIED=1
      TOTAL_REPLACEMENTS=$((TOTAL_REPLACEMENTS + 1))
    fi
    
    # src="/path" → src="./path"
    if grep -qE 'src="/[^/]' "$file" 2>/dev/null; then
      sed -i 's|src="/\([^"]*\)"|src="./\1"|g' "$file"
      echo "    ✓ Fixed src=\"/path\" → src=\"./path\""
      MODIFIED=1
      TOTAL_REPLACEMENTS=$((TOTAL_REPLACEMENTS + 1))
    fi
    
    if grep -qE "src='/[^/]" "$file" 2>/dev/null; then
      sed -i "s|src='/\([^']*\)'|src='./\1'|g" "$file"
      MODIFIED=1
      TOTAL_REPLACEMENTS=$((TOTAL_REPLACEMENTS + 1))
    fi
    
    # url(/path) → url(./path)
    if grep -qE 'url\(/[^/]' "$file" 2>/dev/null; then
      sed -i 's|url(/\([^)]*\))|url(./\1)|g' "$file"
      sed -i "s|url('/\([^']*\)')|url('./\1')|g" "$file"
      sed -i 's|url("/\([^"]*\)")|url(\"./\1\")|g' "$file"
      echo "    ✓ Fixed url(/path) → url(./path)"
      MODIFIED=1
      TOTAL_REPLACEMENTS=$((TOTAL_REPLACEMENTS + 1))
    fi
    
  else
    # SUBPATH DEPLOYMENT: /path → /base/path
    # Fixed regex patterns to capture entire path
    
    # href="/path" → href="/base/path"
    if grep -qE 'href="/[^/]' "$file" 2>/dev/null && ! grep -q "href=\"$BASE_HREF/" "$file" 2>/dev/null; then
      sed -i "s|href=\"/\([^\"]*\)\"|href=\"$BASE_HREF/\1\"|g" "$file"
      echo "    ✓ Prefixed href=\"/...\" with BASE_HREF"
      MODIFIED=1
      TOTAL_REPLACEMENTS=$((TOTAL_REPLACEMENTS + 1))
    fi
    
    if grep -qE "href='/[^/]" "$file" 2>/dev/null && ! grep -q "href='$BASE_HREF/" "$file" 2>/dev/null; then
      sed -i "s|href='/\([^']*\)'|href='$BASE_HREF/\1'|g" "$file"
      MODIFIED=1
      TOTAL_REPLACEMENTS=$((TOTAL_REPLACEMENTS + 1))
    fi
    
    # src="/path" → src="/base/path"
    if grep -qE 'src="/[^/]' "$file" 2>/dev/null && ! grep -q "src=\"$BASE_HREF/" "$file" 2>/dev/null; then
      sed -i "s|src=\"/\([^\"]*\)\"|src=\"$BASE_HREF/\1\"|g" "$file"
      echo "    ✓ Prefixed src=\"/...\" with BASE_HREF"
      MODIFIED=1
      TOTAL_REPLACEMENTS=$((TOTAL_REPLACEMENTS + 1))
    fi
    
    if grep -qE "src='/[^/]" "$file" 2>/dev/null && ! grep -q "src='$BASE_HREF/" "$file" 2>/dev/null; then
      sed -i "s|src='/\([^']*\)'|src='$BASE_HREF/\1'|g" "$file"
      MODIFIED=1
      TOTAL_REPLACEMENTS=$((TOTAL_REPLACEMENTS + 1))
    fi
    
    # url(/path) → url(/base/path)
    if grep -qE 'url\(/[^/]' "$file" 2>/dev/null && ! grep -q "url($BASE_HREF/" "$file" 2>/dev/null; then
      sed -i "s|url(/\([^)]*\))|url($BASE_HREF/\1)|g" "$file"
      sed -i "s|url('/\([^']*\)')|url('$BASE_HREF/\1')|g" "$file"
      sed -i "s|url(\"/\([^\"]*\)\")|url(\"$BASE_HREF/\1\")|g" "$file"
      echo "    ✓ Prefixed url(/...) with BASE_HREF"
      MODIFIED=1
      TOTAL_REPLACEMENTS=$((TOTAL_REPLACEMENTS + 1))
    fi
  fi
  
  # 3. Add .html extension to internal page links (GitHub Pages fix)
  # Match: href="./something" or href="something" where:
  # - NOT already ending with .html, .htm, .xml, .txt, .css, .js, .json
  # - NOT a directory path (ending with /)
  # - NOT an anchor (containing #)
  # - NOT external (containing http:// or https://)
  # - NOT a resource file (.jpg, .png, .svg, .gif, .webp, .woff, .woff2, etc.)
  
  if grep -qE 'href="(\./)?[a-zA-Z0-9_-]+"' "$file" 2>/dev/null; then
    # Add .html to internal page links that don't have extensions
    # Pattern: href="./word" or href="word" → href="./word.html" or href="word.html"
    # Exclude if already has extension or ends with /
    
    # For double-quoted hrefs
    sed -i -E 's/href="(\.\/)?([a-zA-Z0-9_-]+)"([^>]*>)/href="\1\2.html"\3/g' "$file"
    
    # For single-quoted hrefs
    sed -i -E "s/href='(\.\/)?([a-zA-Z0-9_-]+)'([^>]*>)/href='\1\2.html'\3/g" "$file"
    
    # Remove .html.html if accidentally doubled
    sed -i 's/\.html\.html/.html/g' "$file"
    
    # Don't add .html to paths that already have other extensions
    sed -i -E 's/\.xml\.html/.xml/g' "$file"
    sed -i -E 's/\.css\.html/.css/g' "$file"
    sed -i -E 's/\.js\.html/.js/g' "$file"
    sed -i -E 's/\.json\.html/.json/g' "$file"
    sed -i -E 's/\.svg\.html/.svg/g' "$file"
    sed -i -E 's/\.png\.html/.png/g' "$file"
    sed -i -E 's/\.jpg\.html/.jpg/g' "$file"
    sed -i -E 's/\.jpeg\.html/.jpeg/g' "$file"
    sed -i -E 's/\.gif\.html/.gif/g' "$file"
    sed -i -E 's/\.webp\.html/.webp/g' "$file"
    sed -i -E 's/\.woff\.html/.woff/g' "$file"
    sed -i -E 's/\.woff2\.html/.woff2/g' "$file"
    sed -i -E 's/\.txt\.html/.txt/g' "$file"
    
    echo "    ✓ Added .html extension to internal page links"
    MODIFIED=1
    TOTAL_REPLACEMENTS=$((TOTAL_REPLACEMENTS + 1))
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