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
  
  # Create a temporary Python script for complex regex
  python3 - "$file" <<'PYTHON_EOF'
import sys
import re

filename = sys.argv[1]

with open(filename, 'r', encoding='utf-8', errors='ignore') as f:
    content = f.read()

# Pattern to add .html before query strings or anchors
# Matches: href="path" or href="path?query" or href="path#anchor"
# But NOT: href="path.ext" or href="http://" or href="#anchor"

def add_html_extension(match):
    quote = match.group(1)  # " or '
    prefix = match.group(2) or ''  # Optional ./ or nothing
    path = match.group(3)  # The actual path
    suffix = match.group(4) or ''  # Optional ?query or #anchor
    
    # Skip if path already has an extension
    if '.' in path.split('/')[-1]:
        return match.group(0)  # Return unchanged
    
    # Skip if it's just an anchor
    if not path:
        return match.group(0)
    
    # Skip external URLs
    if path.startswith('http://') or path.startswith('https://') or path.startswith('//'):
        return match.group(0)
    
    # Add .html before query/anchor
    return f'href={quote}{prefix}{path}.html{suffix}{quote}'

# Match href="path" or href="path?query" or href="path#anchor"
# Supports both " and '
pattern = r'href=(["\'])((\./)?([a-zA-Z0-9/_-]+))(\?[^"\']*)?(#[^"\']*)?(\1)'

def process_href(match):
    quote = match.group(1)
    prefix = match.group(2) or ''
    path_part = match.group(4)
    query = match.group(5) or ''
    anchor = match.group(6) or ''
    
    # Skip if already has extension
    if '.' in path_part.split('/')[-1]:
        return match.group(0)
    
    # Skip external/special
    if not path_part or path_part.startswith('http'):
        return match.group(0)
    
    return f'href={quote}{prefix}{path_part}.html{query}{anchor}{quote}'

content = re.sub(pattern, process_href, content)

with open(filename, 'w', encoding='utf-8', errors='ignore') as f:
    f.write(content)

PYTHON_EOF
  
  if [ $? -eq 0 ]; then
    echo "    ✓ Added .html extension to page links (Python)"
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
