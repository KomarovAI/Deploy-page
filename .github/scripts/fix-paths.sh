#!/bin/bash
# Fix paths for GitHub Pages deployment
# Supports both root deployment (/) and subpath deployment (/project-name/)
# Uses find -exec instead of while loops to preserve changes
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "${YELLOW}✨ Starting path fixing for GitHub Pages...${NC}"
echo "${BLUE}Base href from env: '${BASE_HREF}'${NC}"

# Ensure BASE_HREF is set, default to root if empty
if [ -z "${BASE_HREF}" ] || [ "${BASE_HREF}" = "" ]; then
  BASE_HREF="/"
  echo "${YELLOW}⚠️ BASE_HREF was empty, defaulting to: /${NC}"
fi

echo "${BLUE}Using BASE_HREF: ${BASE_HREF}${NC}"
echo ""

echo "${YELLOW}Ὄa Scanning files...${NC}"
HTML_COUNT=$(find . -type f -name "*.html" 2>/dev/null | wc -l)
CSS_COUNT=$(find . -type f -name "*.css" 2>/dev/null | wc -l)
JS_COUNT=$(find . -type f -name "*.js" 2>/dev/null | wc -l)
echo " Found: $HTML_COUNT HTML, $CSS_COUNT CSS, $JS_COUNT JS files"
echo ""

# ===== HTML FILES =====
if [ "$HTML_COUNT" -gt 0 ]; then
  echo "${YELLOW}📏 Processing HTML files...${NC}"
  # Fix href="/path" → href="./path"
  find . -type f -name "*.html" -exec sed -i 's|href="/\([^"]*\)"|href="./\1"|g' {} \;
  # Fix src="/path" → src="./path"
  find . -type f -name "*.html" -exec sed -i 's|src="/\([^"]*\)"|src="./\1"|g' {} \;
  # Fix href='/path' → href='./path'
  find . -type f -name "*.html" -exec sed -i "s|href='/\([^']*\)'|href='./\1'|g" {} \;
  # Fix src='/path' → src='./path'
  find . -type f -name "*.html" -exec sed -i "s|src='/\([^']*\)'|src='./\1'|g" {} \;
  # Fix data-src="/path" → data-src="./path"
  find . -type f -name "*.html" -exec sed -i 's|data-src="/\([^"]*\)"|data-src="./\1"|g' {} \;
  echo " ✓ All $HTML_COUNT HTML files processed"
  echo ""
fi

# ===== CSS FILES =====
if [ "$CSS_COUNT" -gt 0 ]; then
  echo "${YELLOW}📏 Processing CSS files...${NC}"
  # Fix url(/path/to/file) → url(./path/to/file)
  find . -type f -name "*.css" -exec sed -i 's|url(/\([^)]*\))|url(./\1)|g' {} \;
  # Fix url("/path") → url("./path")
  find . -type f -name "*.css" -exec sed -i 's|url("/\([^"]*\)")|url("./\1")|g' {} \;
  # Fix url('/path') → url('./path')
  find . -type f -name "*.css" -exec sed -i "s|url('/\([^']*\)')|url('./\1')|g" {} \;
  echo " ✓ All $CSS_COUNT CSS files processed"
  echo ""
fi

# ===== JAVASCRIPT FILES =====
if [ "$JS_COUNT" -gt 0 ]; then
  echo "${YELLOW}📏 Processing JavaScript files...${NC}"
  # Fix require('/path') → require('./path')
  find . -type f -name "*.js" -exec sed -i "s|require('/\([^']*\)')|require('./\1')|g" {} \;
  # Fix require("/path") → require("./path")
  find . -type f -name "*.js" -exec sed -i 's|require("/\([^"]*\)")|require("./\1")|g' {} \;
  # Fix fetch('/path') → fetch('./path')
  find . -type f -name "*.js" -exec sed -i "s|fetch('/\([^']*\)')|fetch('./\1')|g" {} \;
  # Fix fetch("/path") → fetch("./path")
  find . -type f -name "*.js" -exec sed -i 's|fetch("/\([^"]*\)")|fetch("./\1")|g' {} \;
  # Fix import/from statements
  find . -type f -name "*.js" -exec sed -i "s|from '/\([^']*\)'|from './\1'|g" {} \;
  find . -type f -name "*.js" -exec sed -i 's|from "/\([^"]*\)"|from "./\1"|g' {} \;
  echo " ✓ All $JS_COUNT JS files processed"
  echo ""
fi

# ===== ADD BASE HREF TO HTML =====
echo "${YELLOW}📏 Adding base href tags...${NC}"
if [ "$BASE_HREF" != "/" ]; then
  find . -type f -name "*.html" | while IFS= read -r file; do
    # Check if file has <head> tag
    if grep -q '<head[^>]*>' "$file" 2>/dev/null; then
      # Check if already has <base href
      if ! grep -q '<base href' "$file" 2>/dev/null; then
        # Add <base href> right after <head> tag
        sed -i '/<head[^>]*>/a\  <base href="'"$BASE_HREF"'" />' "$file" || true
      fi
    fi
  done
  echo " ✓ Base href tag added to HTML files (href='$BASE_HREF')"
else
  echo " ✓ Root deployment (/) - base href not needed"
fi

echo ""
echo "${GREEN}✅ Path fixing completed successfully${NC}"
echo ""
echo "${BLUE}📋 Summary:${NC}"
echo " - HTML files processed: $HTML_COUNT"
echo " - CSS files processed: $CSS_COUNT"
echo " - JS files processed: $JS_COUNT"
echo " - Base href: $BASE_HREF"
