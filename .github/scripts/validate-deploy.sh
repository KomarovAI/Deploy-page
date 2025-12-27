#!/bin/bash
# Validate deployed website
# Checks for common deployment issues
set -e

echo '🔍 Validating deployment...'
echo ''

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if we're in a directory with files
if [ ! -d "." ]; then
  echo "${RED}❌ No directory to validate${NC}"
  exit 1
fi

# Count files
TOTAL_FILES=$(find . -type f -not -path '*/.git/*' -not -path '*/.github/*' 2>/dev/null | wc -l)
HTML_FILES=$(find . -type f -name "*.html" 2>/dev/null | wc -l)
CSS_FILES=$(find . -type f -name "*.css" 2>/dev/null | wc -l)
echo "${BLUE}📊 Files:${NC}"
echo "  - Total: $TOTAL_FILES"
echo "  - HTML: $HTML_FILES"
echo "  - CSS: $CSS_FILES"
echo ""

# Check index.html
if [ -f "index.html" ]; then
  echo "${GREEN}✅ index.html found${NC}"
  SIZE=$(wc -c < "index.html")
  echo "   Size: $SIZE bytes"
  
  # Check if it's not empty
  if [ "$SIZE" -lt 100 ]; then
    echo "${RED}❌ index.html is suspiciously small${NC}"
    exit 1
  fi
else
  echo "${RED}❌ index.html not found${NC}"
  exit 1
fi
echo ""

# Check for base href in subpath deployments
if [ -n "${BASE_HREF}" ] && [ "${BASE_HREF}" != "/" ]; then
  echo "${BLUE}🔍 Checking base href for subpath deployment...${NC}"
  
  if grep -q '<base href' "index.html" 2>/dev/null; then
    BASE_HREF_VALUE=$(grep -o '<base href="[^"]*"' "index.html" | head -1 | sed 's/<base href="\([^"]*\)"/\1/')
    echo "${GREEN}✅ Base href found: ${BASE_HREF_VALUE}${NC}"
    
    # Verify it matches expected BASE_HREF
    if [ "${BASE_HREF_VALUE}" != "${BASE_HREF}" ]; then
      echo "${YELLOW}⚠️  Warning: Base href mismatch (expected: ${BASE_HREF}, found: ${BASE_HREF_VALUE})${NC}"
    fi
  else
    echo "${RED}❌ Missing <base href> tag in index.html for subpath deployment${NC}"
    exit 1
  fi
  echo ""
fi

# Check for broken absolute paths in HTML
echo "${BLUE}🔗 Checking for broken paths in HTML...${NC}"

# Look for remaining absolute paths that should be relative
BROKEN_HREF=$(grep -rh 'href="/[^/]' . --include="*.html" 2>/dev/null | wc -l || echo 0)
BROKEN_SRC=$(grep -rh 'src="/[^/]' . --include="*.html" 2>/dev/null | wc -l || echo 0)

if [ "$BROKEN_HREF" -gt 0 ] || [ "$BROKEN_SRC" -gt 0 ]; then
  echo "${YELLOW}⚠️  Found absolute paths (may cause issues in subpath deployments):${NC}"
  echo "   - href=\"/...\": $BROKEN_HREF"
  echo "   - src=\"/...\": $BROKEN_SRC"
  
  if [ "$BROKEN_HREF" -gt 0 ]; then
    echo "${YELLOW}   Examples:${NC}"
    grep -rh 'href="/[^/]' . --include="*.html" 2>/dev/null | head -3 | sed 's/^/     /'
  fi
  
  # For subpath deployments, this is critical
  if [ -n "${BASE_HREF}" ] && [ "${BASE_HREF}" != "/" ]; then
    echo "${RED}❌ CRITICAL: Absolute paths detected in subpath deployment${NC}"
    echo "${RED}   These paths will NOT work correctly on GitHub Pages${NC}"
    exit 1
  fi
else
  echo "${GREEN}✅ No absolute paths detected${NC}"
fi
echo ""

# Check for broken absolute paths in CSS
echo "${BLUE}🔗 Checking for broken paths in CSS...${NC}"

if [ "$CSS_FILES" -gt 0 ]; then
  BROKEN_CSS_URL=$(grep -rh 'url(/[^/]' . --include="*.css" 2>/dev/null | wc -l || echo 0)
  
  if [ "$BROKEN_CSS_URL" -gt 0 ]; then
    echo "${YELLOW}⚠️  Found absolute paths in CSS:${NC}"
    echo "   - url(/...): $BROKEN_CSS_URL"
    
    if [ -n "${BASE_HREF}" ] && [ "${BASE_HREF}" != "/" ]; then
      echo "${RED}❌ CRITICAL: Absolute CSS paths detected in subpath deployment${NC}"
      exit 1
    fi
  else
    echo "${GREEN}✅ No absolute paths in CSS${NC}"
  fi
else
  echo "${BLUE}   No CSS files to check${NC}"
fi
echo ""

# Check directory structure
echo "${BLUE}📁 Directory structure (top level):${NC}"
find . -maxdepth 1 -type d -not -path '*/\.*' 2>/dev/null | sed 's|^\./||' | sed 's|^|  - |'
find . -maxdepth 1 -type f -not -path '*/\.*' 2>/dev/null | sed 's|^\./||' | sed 's|^|  - |' | head -5
echo ""

# Check for common asset directories
echo "${BLUE}📂 Checking common asset directories...${NC}"
for dir in "assets" "css" "js" "images" "fonts" "static"; do
  if [ -d "$dir" ]; then
    COUNT=$(find "$dir" -type f 2>/dev/null | wc -l)
    echo "${GREEN}  ✓ $dir/ ($COUNT files)${NC}"
  fi
done
echo ""

echo "${GREEN}✅ Validation complete${NC}"
echo ""

if [ -n "${BASE_HREF}" ] && [ "${BASE_HREF}" != "/" ]; then
  echo "${BLUE}ℹ️  Deployment type: SUBPATH (${BASE_HREF})${NC}"
  echo "${BLUE}   Site will be accessible at: https://username.github.io${BASE_HREF}${NC}"
else
  echo "${BLUE}ℹ️  Deployment type: ROOT (/)${NC}"
fi