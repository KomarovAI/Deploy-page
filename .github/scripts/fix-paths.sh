#!/bin/bash
# Fix paths for GitHub Pages deployment
# STRATEGY: Convert absolute paths to relative + add base href for subpaths
set -e

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
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

# SUBPATH DEPLOYMENT: convert absolute paths to relative
echo "${YELLOW}📏 Subpath deployment - converting absolute paths to relative...${NC}"
echo ""

# Step 1: Convert absolute paths in HTML files
if [ "$HTML_COUNT" -gt 0 ]; then
  echo "${BLUE}🔧 Processing HTML files...${NC}"
  
  find . -type f -name "*.html" | while IFS= read -r file; do
    if [ -f "$file" ]; then
      # Count original absolute paths
      ORIG_HREF=$(grep -o 'href="/[^/]' "$file" 2>/dev/null | wc -l || echo 0)
      ORIG_SRC=$(grep -o 'src="/[^/]' "$file" 2>/dev/null | wc -l || echo 0)
      
      # Convert /path → ./path for href and src
      sed -i 's|href="/\([^/]\)|href="./\1|g' "$file"
      sed -i 's|src="/\([^/]\)|src="./\1|g' "$file"
      
      # Fix external URLs that got broken (//cdn, http://, https://)
      sed -i 's|href="\.//|href="//|g' "$file"
      sed -i 's|src="\.//|src="//|g' "$file"
      sed -i 's|href="\./http|href="http|g' "$file"
      sed -i 's|src="\./http|src="http|g' "$file"
      
      # Add <base href> if not present
      if grep -q '<head[^>]*>' "$file" 2>/dev/null; then
        if ! grep -q '<base href' "$file" 2>/dev/null; then
          sed -i '/<head[^>]*>/a\  <base href="'"$BASE_HREF"'" />' "$file"
        fi
      fi
      
      # Count fixed paths
      NEW_HREF=$(grep -o 'href="/[^/]' "$file" 2>/dev/null | wc -l || echo 0)
      NEW_SRC=$(grep -o 'src="/[^/]' "$file" 2>/dev/null | wc -l || echo 0)
      
      FIXED_TOTAL=$((ORIG_HREF + ORIG_SRC - NEW_HREF - NEW_SRC))
      if [ "$FIXED_TOTAL" -gt 0 ]; then
        echo "  ✓ $file: fixed $FIXED_TOTAL paths"
      fi
    fi
  done
  
  echo "${GREEN}✅ HTML files processed${NC}"
  echo ""
fi

# Step 2: Convert absolute paths in CSS files
if [ "$CSS_COUNT" -gt 0 ]; then
  echo "${BLUE}🔧 Processing CSS files...${NC}"
  
  find . -type f -name "*.css" | while IFS= read -r file; do
    if [ -f "$file" ]; then
      # Count original absolute paths
      ORIG_URL=$(grep -o 'url(/[^/]' "$file" 2>/dev/null | wc -l || echo 0)
      
      # Convert url(/path) → url(./path)
      sed -i 's|url(/\([^/]\)|url(./\1|g' "$file"
      sed -i "s|url('/\([^/]\)|url('./\1|g" "$file"
      sed -i 's|url("/\([^/]\)|url("./\1|g' "$file"
      
      # Fix external URLs
      sed -i 's|url(\./|url(|g' "$file"
      sed -i "s|url('\./|url('|g" "$file"
      sed -i 's|url("\./|url("|g' "$file"
      
      # Re-add ./ for non-external URLs
      sed -i 's|url(/\([^/]\)|url(./\1|g' "$file"
      sed -i "s|url('/\([^/]\)|url('./\1|g" "$file"
      sed -i 's|url("/\([^/]\)|url("./\1|g' "$file"
      
      # Count fixed paths
      NEW_URL=$(grep -o 'url(/[^/]' "$file" 2>/dev/null | wc -l || echo 0)
      
      FIXED_TOTAL=$((ORIG_URL - NEW_URL))
      if [ "$FIXED_TOTAL" -gt 0 ]; then
        echo "  ✓ $file: fixed $FIXED_TOTAL paths"
      fi
    fi
  done
  
  echo "${GREEN}✅ CSS files processed${NC}"
  echo ""
fi

echo ""
echo "${GREEN}✅ Path fixing completed${NC}"
echo "${BLUE}Strategy:${NC}"
echo "  1. Converted /path → ./path (absolute → relative)"
echo "  2. Added <base href=\"${BASE_HREF}\"> to HTML"
echo "  3. Preserved external URLs (http://, https://, //)"
echo ""