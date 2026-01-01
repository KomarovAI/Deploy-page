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
  # CRITICAL FIX: Only add .html to hrefs that DON'T already have any file extension
  # Match patterns like:
  #   href="./page-name"
  #   href="page-name"
  #   href="./folder/page-name"
  # But EXCLUDE:
  #   href="./page.html" (already has .html)
  #   href="./file.xml" (has extension)
  #   href="./path/" (directory)
  #   href="#anchor" (anchor)
  #   href="http://..." (external)
  
  # Strategy: Match href values that:
  # 1. Optionally start with ./
  # 2. Contain path segments (letters, numbers, -, _, /)
  # 3. End WITHOUT a dot followed by extension
  # 4. Are not just a directory (don't end with /)
  
  # Pattern explanation:
  # href="(\./)?          - Optional ./ prefix
  # ([a-zA-Z0-9/_-]+)     - Path segments (can include /)
  # "                     - Closing quote
  # (?![^<]*\.)           - Negative lookahead: no dot before next <
  # This prevents matching href="something.ext"
  
  # For double-quoted hrefs without extensions
  if grep -qE 'href="(\./)?[a-zA-Z0-9/_-]+"' "$file" 2>/dev/null; then
    # Only add .html if the href doesn't already contain a dot (indicating an extension)
    # This regex matches href="path" or href="./path" but NOT href="path.html" or href="./path.xml"
    sed -i -E 's|href="((\./)?([a-zA-Z0-9/_-]+))"|href="\1.html"|g' "$file"
    
    # Now remove .html from any that already had extensions (safeguard)
    # If we accidentally added .html to something.xml, fix it back
    sed -i -E 's|href="([^"]*)\.(xml|css|js|json|svg|png|jpg|jpeg|gif|webp|woff|woff2|txt|pdf|zip|ico)\.html"|href="\1.\2"|g' "$file"
    
    # Also handle .html.html case (double application)
    sed -i 's|\.html\.html"|.html"|g' "$file"
    
    # Handle cases where path already contains .html in the middle (like sectors/bars-pubs.html)
    # Pattern: if there's .html somewhere before the quote, don't add another .html at the end
    # This is a cleanup step: href="path.html.html" → href="path.html"
    sed -i -E 's|href="([^"]*\.html)\.html"|href="\1"|g' "$file"
  fi
  
  # For single-quoted hrefs without extensions
  if grep -qE "href='(\./)?[a-zA-Z0-9/_-]+'" "$file" 2>/dev/null; then
    sed -i -E "s|href='((\./)?([a-zA-Z0-9/_-]+))'|href='\1.html'|g" "$file"
    
    # Cleanup for single quotes
    sed -i -E "s|href='([^']*)\.(xml|css|js|json|svg|png|jpg|jpeg|gif|webp|woff|woff2|txt|pdf|zip|ico)\.html'|href='\1.\2'|g" "$file"
    sed -i "s|\.html\.html'|.html'|g" "$file"
    sed -i -E "s|href='([^']*\.html)\.html'|href='\1'|g" "$file"
    
    echo "    ✓ Added .html extension to internal page links (if needed)"
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
