#!/bin/bash
# Fix paths for GitHub Pages deployment
# STRATEGY: base href ONLY for subpaths + preserve external URLs
set -e

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "${YELLOW}✨ Fixing paths for GitHub Pages...${NC}"
echo "${BLUE}BASE_HREF: '${BASE_HREF}'${NC}"

# Default to root
if [ -z "${BASE_HREF}" ] || [ "${BASE_HREF}" = "" ]; then
  BASE_HREF="/"
fi

echo "${BLUE}Using: ${BASE_HREF}${NC}"
echo ""

HTML_COUNT=$(find . -type f -name "*.html" 2>/dev/null | wc -l)
CSS_COUNT=$(find . -type f -name "*.css" 2>/dev/null | wc -l)
JS_COUNT=$(find . -type f -name "*.js" 2>/dev/null | wc -l)
echo "📊 Found: $HTML_COUNT HTML, $CSS_COUNT CSS, $JS_COUNT JS"
echo ""

# ROOT DEPLOYMENT: no changes needed
if [ "$BASE_HREF" = "/" ]; then
  echo "${GREEN}✓ Root deployment - no path changes needed${NC}"
  exit 0
fi

# SUBPATH DEPLOYMENT: add base href only
echo "${YELLOW}📏 Subpath deployment - adding base href...${NC}"

if [ "$HTML_COUNT" -gt 0 ]; then
  find . -type f -name "*.html" | while IFS= read -r file; do
    if grep -q '<head[^>]*>' "$file" 2>/dev/null; then
      if ! grep -q '<base href' "$file" 2>/dev/null; then
        sed -i '/<head[^>]*>/a\  <base href="'"$BASE_HREF"'" />' "$file" || true
      fi
    fi
  done
  echo "${GREEN}✓ Base href added to $HTML_COUNT files${NC}"
fi

echo ""
echo "${GREEN}✅ Path fixing completed${NC}"
echo "${BLUE}Strategy: <base href=\"${BASE_HREF}\"> for all relative paths${NC}"