#!/bin/bash
# Fix absolute paths for GitHub Pages deployment
# This script rewrites absolute paths to relative paths for GitHub Pages
# with robust regex patterns and comprehensive logging

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "${YELLOW}🔧 Starting path fixing for GitHub Pages...${NC}"

echo "${YELLOW}📊 Scanning files...${NC}"
HTML_COUNT=$(find . -type f -name "*.html" 2>/dev/null | wc -l)
CSS_COUNT=$(find . -type f -name "*.css" 2>/dev/null | wc -l)
JS_COUNT=$(find . -type f -name "*.js" 2>/dev/null | wc -l)
echo "  Found: $HTML_COUNT HTML, $CSS_COUNT CSS, $JS_COUNT JS files"

# Counter for changes
CHANGES=0

# ===== HTML FILES =====
echo "${YELLOW}📝 Processing HTML files...${NC}"
find . -type f -name "*.html" 2>/dev/null | while read file; do
  BEFORE=$(wc -c < "$file")
  
  # Fix href with double quotes: href="/path" → href="./path"
  sed -i 's|href="/\([^"]*\)"|href="./\1"|g' "$file"
  
  # Fix src with double quotes: src="/path" → src="./path"
  sed -i 's|src="/\([^"]*\)"|src="./\1"|g' "$file"
  
  # Fix href with single quotes: href='/path' → href='./path'
  sed -i "s|href='/\([^']*\)'|href='./\1'|g" "$file"
  
  # Fix src with single quotes: src='/path' → src='./path'
  sed -i "s|src='/\([^']*\)'|src='./\1'|g" "$file"
  
  # Fix data-* attributes: data-src="/path" → data-src="./path"
  sed -i 's|data-src="/\([^"]*\)"|data-src="./\1"|g' "$file"
  
  AFTER=$(wc -c < "$file")
  if [ "$BEFORE" != "$AFTER" ]; then
    echo "  ✓ Fixed $file"
  fi
done

# ===== CSS FILES =====
echo "${YELLOW}📝 Processing CSS files...${NC}"
find . -type f -name "*.css" 2>/dev/null | while read file; do
  BEFORE=$(wc -c < "$file")
  
  # Fix url(/path/to/file) → url(./path/to/file)
  sed -i 's|url(/\([^)]*\))|url(./\1)|g' "$file"
  
  # Fix url("/path") → url("./path")
  sed -i 's|url("/\([^"]*\)")|url("./\1")|g' "$file"
  
  # Fix url('/path') → url('./path')
  sed -i "s|url('/\([^']*\)')|url('./\1')|g" "$file"
  
  AFTER=$(wc -c < "$file")
  if [ "$BEFORE" != "$AFTER" ]; then
    echo "  ✓ Fixed $file"
  fi
done

# ===== JAVASCRIPT FILES =====
echo "${YELLOW}📝 Processing JavaScript files...${NC}"
find . -type f -name "*.js" 2>/dev/null | while read file; do
  BEFORE=$(wc -c < "$file")
  
  # Fix require('/path') → require('./path')
  sed -i "s|require('/\([^']*\)')|require('./\1')|g" "$file"
  
  # Fix require("/path") → require("./path")
  sed -i 's|require("/\([^"]*\)")|require("./\1")|g' "$file"
  
  # Fix fetch('/path') → fetch('./path')
  sed -i "s|fetch('/\([^']*\)')|fetch('./\1')|g" "$file"
  
  # Fix fetch("/path") → fetch("./path")
  sed -i 's|fetch("/\([^"]*\)")|fetch("./\1")|g' "$file"
  
  # Fix import/from statements
  sed -i "s|from '/\([^']*\)'|from './\1'|g" "$file"
  sed -i 's|from "/\([^"]*\)"|from "./\1"|g' "$file"
  
  # Fix XMLHttpRequest paths: '/path' → './path'
  sed -i "s|'/\([^']*\)'|'./\1'|g" "$file"
  sed -i 's|"/\([^"]*\)"|"./\1"|g' "$file"
  
  AFTER=$(wc -c < "$file")
  if [ "$BEFORE" != "$AFTER" ]; then
    echo "  ✓ Fixed $file"
  fi
done

# ===== SPECIAL HANDLING =====
echo "${YELLOW}📝 Processing special cases...${NC}"

# Fix remaining /wp-content/ paths (legacy)
find . -type f \( -name "*.html" -o -name "*.css" -o -name "*.js" \) 2>/dev/null | while read file; do
  if grep -q '/wp-content/' "$file" 2>/dev/null; then
    sed -i 's|/wp-content/|./wp-content/|g' "$file"
    echo "  ✓ Fixed wp-content paths in $file"
  fi
done

# ===== VALIDATION =====
echo "${YELLOW}🔍 Validating paths...${NC}"

# Check for any remaining absolute paths that we might have missed
ABSOLUTE_COUNT=$(grep -r 'href="/[^.]' . --include="*.html" 2>/dev/null | wc -l || echo 0)
if [ "$ABSOLUTE_COUNT" -gt 0 ]; then
  echo "${YELLOW}⚠️  Warning: Found $ABSOLUTE_COUNT absolute paths that might need attention${NC}"
else
  echo "  ✓ No unprocessed absolute paths found"
fi

# Verify relative paths are present
RELATIVE_COUNT=$(grep -r 'href="\./' . --include="*.html" 2>/dev/null | wc -l || echo 0)
echo "  ✓ Found $RELATIVE_COUNT relative paths"

echo "${GREEN}✅ Path fixing completed successfully${NC}"
echo ""
echo "${BLUE}📋 Summary:${NC}"
echo "  - HTML files processed: $HTML_COUNT"
echo "  - CSS files processed: $CSS_COUNT"
echo "  - JS files processed: $JS_COUNT"
echo "  - Relative paths detected: $RELATIVE_COUNT"
