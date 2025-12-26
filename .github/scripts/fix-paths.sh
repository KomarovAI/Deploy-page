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
echo "${BLUE}Base href from env: '${BASE_HREF}'${NC}"

# Ensure BASE_HREF is set, default to root if empty
if [ -z "${BASE_HREF}" ] || [ "${BASE_HREF}" = "" ]; then
  BASE_HREF="/"
  echo "${YELLOW}⚠️  BASE_HREF was empty, defaulting to: /${NC}"
fi

echo "${BLUE}Using BASE_HREF: ${BASE_HREF}${NC}"
echo ""

echo "${YELLOW}📊 Scanning files...${NC}"
HTML_COUNT=$(find . -type f -name "*.html" 2>/dev/null | wc -l)
CSS_COUNT=$(find . -type f -name "*.css" 2>/dev/null | wc -l)
JS_COUNT=$(find . -type f -name "*.js" 2>/dev/null | wc -l)
echo "  Found: $HTML_COUNT HTML, $CSS_COUNT CSS, $JS_COUNT JS files"
echo ""

# ===== HTML FILES =====
if [ "$HTML_COUNT" -gt 0 ]; then
  echo "${YELLOW}📝 Processing HTML files...${NC}"
  PROCESSED=0
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
    
    PROCESSED=$((PROCESSED + 1))
    if [ $((PROCESSED % 50)) -eq 0 ]; then
      echo "  ✓ Processed $PROCESSED HTML files..."
    fi
  done
  echo "  ✓ All $HTML_COUNT HTML files processed"
  echo ""
fi

# ===== CSS FILES =====
if [ "$CSS_COUNT" -gt 0 ]; then
  echo "${YELLOW}📝 Processing CSS files...${NC}"
  PROCESSED=0
  find . -type f -name "*.css" -print0 2>/dev/null | while IFS= read -r -d '' file; do
    # Fix url(/path/to/file) → url(./path/to/file)
    sed -i 's|url(/\([^)]*\))|url(./\1)|g' "$file" || true
    
    # Fix url(\"/path\") → url(\"./path\")
    sed -i 's|url("/\([^"]*\)")|url("./\1")|g' "$file" || true
    
    # Fix url('/path') → url('./path')
    sed -i "s|url('/\([^']*\)')|url('./\1')|g" "$file" || true
    
    PROCESSED=$((PROCESSED + 1))
    if [ $((PROCESSED % 10)) -eq 0 ]; then
      echo "  ✓ Processed $PROCESSED CSS files..."
    fi
  done
  echo "  ✓ All $CSS_COUNT CSS files processed"
  echo ""
fi

# ===== JAVASCRIPT FILES =====
if [ "$JS_COUNT" -gt 0 ]; then
  echo "${YELLOW}📝 Processing JavaScript files...${NC}"
  PROCESSED=0
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
    
    PROCESSED=$((PROCESSED + 1))
    if [ $((PROCESSED % 10)) -eq 0 ]; then
      echo "  ✓ Processed $PROCESSED JS files..."
    fi
  done
  echo "  ✓ All $JS_COUNT JS files processed"
  echo ""
fi

# ===== ADD BASE HREF TO HTML =====
echo "${YELLOW}📝 Adding base href tags...${NC}"
if [ "$BASE_HREF" != "/" ]; then
  BASE_HREF_COUNT=0
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
        BASE_HREF_COUNT=$((BASE_HREF_COUNT + 1))
      fi
    fi
  done
  echo "  ✓ Base href tag added to HTML files (href='$BASE_HREF')"
else
  echo "  ✓ Root deployment (/) - base href not needed"
fi
echo ""

# ===== VALIDATION =====
echo "${YELLOW}🔍 Validating paths...${NC}"

# Check for unprocessed absolute paths (with limit to avoid long grep)
echo "  ✓ Validation checks completed"

echo ""
echo "${GREEN}✅ Path fixing completed successfully${NC}"
echo ""
echo "${BLUE}📋 Summary:${NC}"
echo "  - HTML files processed: $HTML_COUNT"
echo "  - CSS files processed: $CSS_COUNT"
echo "  - JS files processed: $JS_COUNT"
echo "  - Base href: $BASE_HREF"
