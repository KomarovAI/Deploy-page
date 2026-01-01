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

# Error counter (soft validation)
ERROR_COUNT=0
WARNING_COUNT=0

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
    ERROR_COUNT=$((ERROR_COUNT + 1))
  fi
else
  echo "${RED}❌ index.html not found${NC}"
  ERROR_COUNT=$((ERROR_COUNT + 1))
fi
echo ""

# Check for base href in subpath deployments
if [ -n "${BASE_HREF}" ] && [ "${BASE_HREF}" != "/" ]; then
  echo "${BLUE}🔍 Checking base href for subpath deployment...${NC}"
  
  if grep -q '<base href' "index.html" 2>/dev/null; then
    BASE_HREF_VALUE=$(grep -o '<base href="[^"]*"' "index.html" | head -1 | sed 's/<base href="\([^"]*\)"/\1/')
    echo "${GREEN}✅ Base href found: ${BASE_HREF_VALUE}${NC}"
    
    # Verify it matches expected BASE_HREF
    if [ "${BASE_HREF_VALUE}" != "${BASE_HREF}" ] && [ "${BASE_HREF_VALUE}" != "${BASE_HREF}/" ]; then
      echo "${YELLOW}⚠️  Warning: Base href mismatch (expected: ${BASE_HREF}, found: ${BASE_HREF_VALUE})${NC}"
      WARNING_COUNT=$((WARNING_COUNT + 1))
    fi
  else
    echo "${YELLOW}⚠️  Warning: Missing <base href> tag in index.html for subpath deployment${NC}"
    echo "${YELLOW}   This may cause navigation issues${NC}"
    WARNING_COUNT=$((WARNING_COUNT + 1))
  fi
  echo ""
fi

# Check for broken absolute paths in HTML
echo "${BLUE}🔗 Checking for problematic paths in HTML...${NC}"

# IMPROVED REGEX: Match actual absolute paths
# Pattern: href="/something" or src="/something" (but not href="//external.com")
BROKEN_HREF=0
BROKEN_SRC=0
DOUBLE_SLASH_HREF=0
DOUBLE_SLASH_SRC=0

if [ "$HTML_FILES" -gt 0 ]; then
  # Count absolute paths (href="/path" but NOT href="//external")
  BROKEN_HREF=$(grep -rh 'href="/[^/"]' . --include="*.html" 2>/dev/null | grep -v 'href="//' | wc -l || echo 0)
  BROKEN_SRC=$(grep -rh 'src="/[^/"]' . --include="*.html" 2>/dev/null | grep -v 'src="//' | wc -l || echo 0)
  
  # Check for double slashes (common bug after path fixing)
  DOUBLE_SLASH_HREF=$(grep -rh 'href="[^"]*//[^/]' . --include="*.html" 2>/dev/null | wc -l || echo 0)
  DOUBLE_SLASH_SRC=$(grep -rh 'src="[^"]*//[^/]' . --include="*.html" 2>/dev/null | wc -l || echo 0)
  
  if [ "$BROKEN_HREF" -gt 0 ] || [ "$BROKEN_SRC" -gt 0 ]; then
    echo "${YELLOW}⚠️  Found root-relative paths (potential issues):${NC}"
    echo "   - href=\"/...\": $BROKEN_HREF"
    echo "   - src=\"/...\": $BROKEN_SRC"
    
    if [ "$BROKEN_HREF" -gt 0 ]; then
      echo "${YELLOW}   Examples:${NC}"
      grep -rh 'href="/[^/"]' . --include="*.html" 2>/dev/null | grep -v 'href="//' | head -3 | sed 's/^/     /'
    fi
    
    # For subpath deployments, this is MORE critical (warning, not error)
    if [ -n "${BASE_HREF}" ] && [ "${BASE_HREF}" != "/" ]; then
      echo "${YELLOW}⚠️  WARNING: Root-relative paths may not work correctly in subpath deployment (${BASE_HREF})${NC}"
      WARNING_COUNT=$((WARNING_COUNT + 1))
    else
      echo "${BLUE}ℹ️  Info: Root-relative paths found (acceptable for root deployment)${NC}"
    fi
  else
    echo "${GREEN}✅ No problematic root-relative paths detected${NC}"
  fi
  
  # Check for double slashes (CRITICAL BUG indicator)
  if [ "$DOUBLE_SLASH_HREF" -gt 0 ] || [ "$DOUBLE_SLASH_SRC" -gt 0 ]; then
    echo "${RED}❌ CRITICAL: Double slashes detected!${NC}"
    echo "   - href with //: $DOUBLE_SLASH_HREF"
    echo "   - src with //: $DOUBLE_SLASH_SRC"
    echo "${RED}   This indicates a bug in path fixing logic${NC}"
    
    # Show examples
    if [ "$DOUBLE_SLASH_HREF" -gt 0 ]; then
      echo "   Examples:"
      grep -rh 'href="[^"]*//[^/]' . --include="*.html" 2>/dev/null | head -3 | sed 's/^/     /'
    fi
    
    ERROR_COUNT=$((ERROR_COUNT + 1))
  else
    echo "${GREEN}✅ No double slashes detected${NC}"
  fi
fi
echo ""

# Check for broken absolute paths in CSS
echo "${BLUE}🔗 Checking for problematic paths in CSS...${NC}"

if [ "$CSS_FILES" -gt 0 ]; then
  BROKEN_CSS_URL=$(grep -rh 'url(/[^/)]' . --include="*.css" 2>/dev/null | wc -l || echo 0)
  DOUBLE_SLASH_CSS=$(grep -rh 'url([^)]*//[^/)]' . --include="*.css" 2>/dev/null | wc -l || echo 0)
  
  if [ "$BROKEN_CSS_URL" -gt 0 ]; then
    echo "${YELLOW}⚠️  Found root-relative paths in CSS:${NC}"
    echo "   - url(/...): $BROKEN_CSS_URL"
    
    if [ -n "${BASE_HREF}" ] && [ "${BASE_HREF}" != "/" ]; then
      echo "${YELLOW}⚠️  WARNING: CSS paths may not work correctly in subpath deployment${NC}"
      WARNING_COUNT=$((WARNING_COUNT + 1))
    fi
  else
    echo "${GREEN}✅ No problematic CSS paths${NC}"
  fi
  
  # Check double slashes in CSS
  if [ "$DOUBLE_SLASH_CSS" -gt 0 ]; then
    echo "${RED}❌ CRITICAL: Double slashes in CSS detected!${NC}"
    echo "   - url with //: $DOUBLE_SLASH_CSS"
    ERROR_COUNT=$((ERROR_COUNT + 1))
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
for dir in "assets" "css" "js" "images" "fonts" "static" "wp-content" "services"; do
  if [ -d "$dir" ]; then
    COUNT=$(find "$dir" -type f 2>/dev/null | wc -l)
    echo "${GREEN}  ✓ $dir/ ($COUNT files)${NC}"
  fi
done
echo ""

# Final summary
echo "========================================"
if [ $ERROR_COUNT -gt 0 ]; then
  echo "${RED}❌ Validation FAILED${NC}"
  echo "${RED}   Errors: $ERROR_COUNT${NC}"
  echo "${YELLOW}   Warnings: $WARNING_COUNT${NC}"
  echo ""
  echo "${RED}Critical issues must be fixed before deployment${NC}"
  exit 1
elif [ $WARNING_COUNT -gt 0 ]; then
  echo "${YELLOW}⚠️  Validation PASSED with warnings${NC}"
  echo "${YELLOW}   Warnings: $WARNING_COUNT${NC}"
  echo ""
  echo "${YELLOW}Deployment will proceed, but issues may occur${NC}"
else
  echo "${GREEN}✅ Validation PASSED${NC}"
  echo "${GREEN}   No errors or warnings${NC}"
fi
echo ""

if [ -n "${BASE_HREF}" ] && [ "${BASE_HREF}" != "/" ]; then
  echo "${BLUE}ℹ️  Deployment type: SUBPATH (${BASE_HREF})${NC}"
  echo "${BLUE}   Site will be accessible at: https://username.github.io${BASE_HREF}${NC}"
else
  echo "${BLUE}ℹ️  Deployment type: ROOT (/)${NC}"
fi

exit 0