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
FILES_MODIFIED=0

for file in $HTML_FILES; do
  echo "  Processing: $file"
  
  # Track if file was modified
  MODIFIED=0
  
  # Create backup for comparison
  cp "$file" "$file.backup"
  
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
  fi
  
  # 2. Fix root-relative paths based on BASE_HREF
  if [ "$BASE_HREF" = "" ] || [ "$BASE_HREF" = "/" ]; then
    # ROOT DEPLOYMENT: /path → ./path
    # Only replace if NOT already relative (idempotent)
    
    # IMPROVED: Handle query strings and anchors
    # href="/path?query" → href="./path?query"
    # href="/path#anchor" → href="./path#anchor"
    # href="/path?q=1#top" → href="./path?q=1#top"
    
    if grep -qE 'href="/[^/]' "$file" 2>/dev/null; then
      # This regex preserves query strings and anchors
      sed -i 's|href="/\([^"]*\)"|href="./\1"|g' "$file"
      echo "    ✓ Fixed href=\"/...\" → href=\"./...\""
      MODIFIED=1
    fi
    
    if grep -qE "href='/[^/]" "$file" 2>/dev/null; then
      sed -i "s|href='/\([^']*\)'|href='./\1'|g" "$file"
      MODIFIED=1
    fi
    
    # src="/path" → src="./path"
    if grep -qE 'src="/[^/]' "$file" 2>/dev/null; then
      sed -i 's|src="/\([^"]*\)"|src="./\1"|g' "$file"
      echo "    ✓ Fixed src=\"/...\" → src=\"./...\""
      MODIFIED=1
    fi
    
    if grep -qE "src='/[^/]" "$file" 2>/dev/null; then
      sed -i "s|src='/\([^']*\)'|src='./\1'|g" "$file"
      MODIFIED=1
    fi
    
    # url(/path) → url(./path)
    if grep -qE 'url\(/[^/]' "$file" 2>/dev/null; then
      sed -i 's|url(/\([^)]*\))|url(./\1)|g' "$file"
      sed -i "s|url('/\([^']*\)')|url('./\1')|g" "$file"
      sed -i 's|url("/\([^"]*\)")|url(\"./\1\")|g' "$file"
      echo "    ✓ Fixed url(/...) → url(./...)"
      MODIFIED=1
    fi
    
  else
    # SUBPATH DEPLOYMENT: /path → /base/path
    
    if grep -qE 'href="/[^/]' "$file" 2>/dev/null && ! grep -q "href=\"$BASE_HREF/" "$file" 2>/dev/null; then
      sed -i "s|href=\"/\([^\"]*\)\"|href=\"$BASE_HREF/\1\"|g" "$file"
      echo "    ✓ Prefixed href with BASE_HREF"
      MODIFIED=1
    fi
    
    if grep -qE "href='/[^/]" "$file" 2>/dev/null && ! grep -q "href='$BASE_HREF/" "$file" 2>/dev/null; then
      sed -i "s|href='/\([^']*\)'|href='$BASE_HREF/\1'|g" "$file"
      MODIFIED=1
    fi
    
    if grep -qE 'src="/[^/]' "$file" 2>/dev/null && ! grep -q "src=\"$BASE_HREF/" "$file" 2>/dev/null; then
      sed -i "s|src=\"/\([^\"]*\)\"|src=\"$BASE_HREF/\1\"|g" "$file"
      echo "    ✓ Prefixed src with BASE_HREF"
      MODIFIED=1
    fi
    
    if grep -qE "src='/[^/]" "$file" 2>/dev/null && ! grep -q "src='$BASE_HREF/" "$file" 2>/dev/null; then
      sed -i "s|src='/\([^']*\)'|src='$BASE_HREF/\1'|g" "$file"
      MODIFIED=1
    fi
    
    if grep -qE 'url\(/[^/]' "$file" 2>/dev/null && ! grep -q "url($BASE_HREF/" "$file" 2>/dev/null; then
      sed -i "s|url(/\([^)]*\))|url($BASE_HREF/\1)|g" "$file"
      sed -i "s|url('/\([^']*\)')|url('$BASE_HREF/\1')|g" "$file"
      sed -i "s|url(\"/\([^\"]*\)\")|url(\"$BASE_HREF/\1\")|g" "$file"
      echo "    ✓ Prefixed url(...) with BASE_HREF"
      MODIFIED=1
    fi
  fi
  
  # 3. Add .html extension to internal page links (GitHub Pages fix)
  # IMPROVED: Better handling of query strings and anchors
  # Examples:
  #   href="./services" → href="./services.html"
  #   href="./services?tab=1" → href="./services.html?tab=1"
  #   href="./services#about" → href="./services.html#about"
  #   href="./services.html" → href="./services.html" (unchanged)
  
  # Strategy: Find hrefs without extensions and add .html before query/anchor
  
  # Pattern: href="(path)(?query)(#anchor)"
  # Transform to: href="(path).html(?query)(#anchor)"
  
  # For double-quoted hrefs: href="path" or href="path?query" or href="path#anchor"
  # Match pattern: href="(./)?[a-zA-Z0-9/_-]+" followed by optional ? or #
  # But NOT if path already contains a dot (extension)
  
  if grep -qE 'href="(\./)?[a-zA-Z0-9/_-]+([?#]|")' "$file" 2>/dev/null; then
    # Step 1: Add .html to paths without extensions
    # Match: href="path" or href="path?" or href="path#"
    # But NOT: href="path.ext" or href="path.ext?" or href="path.ext#"
    
    # Transform: href="services?tab=1" → href="services.html?tab=1"
    sed -i -E 's|href="((\./)?([a-zA-Z0-9/_-]+))(\?[^"]*)?"|href="\1.html\4"|g' "$file"
    sed -i -E 's|href="((\./)?([a-zA-Z0-9/_-]+))(#[^"]*)?"|href="\1.html\4"|g' "$file"
    
    # Step 2: Clean up files that already had extensions
    # Pattern: href="file.ext.html" → href="file.ext"
    sed -i -E 's|href="([^"]*)\.(xml|css|js|json|svg|png|jpg|jpeg|gif|webp|woff|woff2|txt|pdf|zip|ico)\.html"|href="\1.\2"|g' "$file"
    
    # Step 3: Fix double .html.html
    sed -i 's|\.html\.html|.html|g' "$file"
    
    # Step 4: Fix cases where .html was in the middle
    sed -i -E 's|href="([^"]*\.html)\.html"|href="\1"|g' "$file"
    
    echo "    ✓ Added .html extension to page links (preserving queries/anchors)"
    MODIFIED=1
  fi
  
  # Same for single-quoted hrefs
  if grep -qE "href='(\./)?[a-zA-Z0-9/_-]+([?#]|')" "$file" 2>/dev/null; then
    sed -i -E "s|href='((\./)?([a-zA-Z0-9/_-]+))(\?[^']*)?'|href='\1.html\4'|g" "$file"
    sed -i -E "s|href='((\./)?([a-zA-Z0-9/_-]+))(#[^']*)?'|href='\1.html\4'|g" "$file"
    
    sed -i -E "s|href='([^']*)\.(xml|css|js|json|svg|png|jpg|jpeg|gif|webp|woff|woff2|txt|pdf|zip|ico)\.html'|href='\1.\2'|g" "$file"
    sed -i "s|\.html\.html|.html|g" "$file"
    sed -i -E "s|href='([^']*\.html)\.html'|href='\1'|g" "$file"
    
    MODIFIED=1
  fi
  
  # Compare with backup to count actual changes
  if ! diff -q "$file" "$file.backup" > /dev/null 2>&1; then
    CHANGE_COUNT=$(diff "$file" "$file.backup" | grep -c '^[<>]' || echo 0)
    echo "    📝 $CHANGE_COUNT lines changed"
    FILES_MODIFIED=$((FILES_MODIFIED + 1))
    TOTAL_REPLACEMENTS=$((TOTAL_REPLACEMENTS + CHANGE_COUNT))
  else
    echo "    → No changes needed (already correct)"
  fi
  
  # Remove backup
  rm -f "$file.backup"
done

echo ""
echo "✅ Path fixing complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Total files scanned: $HTML_COUNT"
echo "Files modified: $FILES_MODIFIED"
echo "Total line changes: $TOTAL_REPLACEMENTS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ $FILES_MODIFIED -eq 0 ]; then
  echo "ℹ️  All files were already correct - no changes needed"
else
  echo "✨ Successfully updated $FILES_MODIFIED file(s) for GitHub Pages"
fi

exit 0
