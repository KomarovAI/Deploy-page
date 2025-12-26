#!/bin/bash
# Fix paths for GitHub Pages deployment
# Supports both root deployment (/) and subpath deployment (/project-name/)
# Uses relative paths for maximum compatibility

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "${YELLOW}🔧 Starting path fixing for GitHub Pages...${NC}"
echo "${BLUE}Base href: ${BASE_HREF}${NC}"
echo ""

echo "${YELLOW}📊 Scanning files...${NC}"
HTML_COUNT=$(find . -type f -name "*.html" 2>/dev/null | wc -l)
CSS_COUNT=$(find . -type f -name "*.css" 2>/dev/null | wc -l)
JS_COUNT=$(find . -type f -name "*.js" 2>/dev/null | wc -l)
echo "  Found: $HTML_COUNT HTML, $CSS_COUNT CSS, $JS_COUNT JS files"
echo ""

# ===== HTML FILES =====
echo "${YELLOW}📝 Processing HTML files...${NC}"
find . -type f -name "*.html" -print0 2>/dev/null | while IFS= read -r -d '' file; do
  # Fix href with double quotes: href=\"/path\" → href=\"./path\"
  sed -i 's|href="/\([^"]*\)"|href="./\1"|g' "$file" || true
  
  # Fix src with double quotes: src=\"/path\" → src=\"./path\"
  sed -i 's|src="/\([^"]*\)"|src="./\1"|g' "$file" || true
  
  # Fix href with single quotes: href='/path' → href='./path'
  sed -i "s|href='/\([^']*\)'|href='./\1'|g" "$file" || true
  
  # Fix src with single quotes: src='/path' → src='./path'
  sed -i "s|src='/\([^']*\)'|src='./\1'|g" "$file" || true
  
  # Fix data-* attributes: data-src=\"/path\" → data-src=\"./path\"
  sed -i 's|data-src="/\([^"]*\)"|data-src="./\1"|g' "$file" || true
done
echo "  ✓ HTML files processed"
echo ""

# ===== CSS FILES =====
echo "${YELLOW}📝 Processing CSS files...${NC}"
find . -type f -name "*.css" -print0 2>/dev/null | while IFS= read -r -d '' file; do
  # Fix url(/path/to/file) → url(./path/to/file)
  sed -i 's|url(/\([^)]*\))|url(./\1)|g' "$file" || true
  
  # Fix url(\"/path\") → url(\"./path\")
  sed -i 's|url("/\([^"]*\)")|url("./\1")|g' "$file" || true
  
  # Fix url('/path') → url('./path')
  sed -i "s|url('/\([^']*\)')|url('./\1')|g" "$file" || true
done
echo "  ✓ CSS files processed"
echo ""

# ===== JAVASCRIPT FILES =====
echo "${YELLOW}📝 Processing JavaScript files...${NC}"
find . -type f -name "*.js" -print0 2>/dev/null | while IFS= read -r -d '' file; do
  # Fix require('/path') → require('./path')
  sed -i "s|require('/\([^']*\)')|require('./\1')|g" "$file" || true
  
  # Fix require(\"/path\") → require(\"./path\")
  sed -i 's|require("/\([^"]*\)")|require("./\1")|g' "$file" || true
  
  # Fix fetch('/path') → fetch('./path')
  sed -i "s|fetch('/\([^']*\)')|fetch('./\1')|g" "$file" || true
  
  # Fix fetch(\"/path\") → fetch(\"./path\")
  sed -i 's|fetch("/\([^"]*\)")|fetch("./\1")|g' "$file" || true
  
  # Fix import/from statements
  sed -i "s|from '/\([^']*\)'|from './\1'|g" "$file" || true
  sed -i 's|from "/\([^"]*\)"|from "./\1"|g' "$file" || true
done
echo "  ✓ JavaScript files processed"
echo ""

# ===== ADD BASE HREF TO HTML =====
echo "${YELLOW}📝 Adding base href tags...${NC}"
if [ "$BASE_HREF" != "/" ]; then
  find . -type f -name "*.html" -print0 2>/dev/null | while IFS= read -r -d '' file; do
    # Check if file has <head> tag
    if grep -q '<head[^>]*>' "$file" 2>/dev/null; then
      # Check if already has <base href
      if ! grep -q '<base href' "$file" 2>/dev/null; then
        # Add <base href> right after <head> tag
        awk '/<head[^>]*>/{print; print "    <base href=\"'"$BASE_HREF"'\" />"; next} {print}' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file" || {
          echo "${RED}❌ Failed to add base href to $file${NC}" >&2
          exit 1
        }
      fi
    fi
  done
  echo "  ✓ Base href tags added to HTML files (href='$BASE_HREF')"
else
  echo "  ✓ Root deployment (/) - base href not needed"
fi
echo ""

# ===== VALIDATION =====
echo "${YELLOW}🔍 Validating paths...${NC}"

# Check for unprocessed absolute paths
ABSOLUTE_COUNT=$(grep -r 'href="/[^"#.]' . --include="*.html" 2>/dev/null | wc -l || echo 0)
if [ "$ABSOLUTE_COUNT" -gt 0 ]; then
  echo "${YELLOW}⚠️  Warning: Found $ABSOLUTE_COUNT absolute paths that might need attention${NC}"
else
  echo "  ✓ No unprocessed absolute paths found"
fi

# Verify relative paths are present
RELATIVE_COUNT=$(grep -r 'href="\./' . --include="*.html" 2>/dev/null | wc -l || echo 0)
echo "  ✓ Found $RELATIVE_COUNT relative paths"

# Check base href tags if not root
if [ "$BASE_HREF" != "/" ]; then
  BASE_HREF_COUNT=$(grep -r '<base href' . --include="*.html" 2>/dev/null | wc -l || echo 0)
  echo "  ✓ Found $BASE_HREF_COUNT base href tags"
fi

echo ""
echo "${GREEN}✅ Path fixing completed successfully${NC}"
echo ""
echo "${BLUE}📋 Summary:${NC}"
echo "  - HTML files processed: $HTML_COUNT"
echo "  - CSS files processed: $CSS_COUNT"
echo "  - JS files processed: $JS_COUNT"
echo "  - Relative paths detected: $RELATIVE_COUNT"
echo "  - Base href: $BASE_HREF"
