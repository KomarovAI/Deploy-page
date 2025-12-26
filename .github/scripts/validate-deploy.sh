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
echo "${BLUE}📊 Files:${NC}"
echo "  - Total: $TOTAL_FILES"
echo "  - HTML: $HTML_FILES"
echo ""

# Check index.html
if [ -f "index.html" ]; then
  echo "${GREEN}✅ index.html found${NC}"
  SIZE=$(wc -c < "index.html")
  echo "   Size: $SIZE bytes"
else
  echo "${YELLOW}⚠️  index.html not found${NC}"
fi
echo ""

# Check for broken absolute paths
echo "${BLUE}🔗 Checking for broken paths...${NC}"

# Look for remaining absolute paths that should be relative
BROKEN_HREF=$(grep -r 'href="/[^/]' . --include="*.html" 2>/dev/null | grep -v '^\.\/' | wc -l || true)
BROKEN_SRC=$(grep -r 'src="/[^/]' . --include="*.html" 2>/dev/null | grep -v '^\.\/' | wc -l || true)

if [ "$BROKEN_HREF" -gt 0 ] || [ "$BROKEN_SRC" -gt 0 ]; then
  echo "${YELLOW}⚠️  Found potentially broken absolute paths:${NC}"
  echo "   - href issues: $BROKEN_HREF"
  echo "   - src issues: $BROKEN_SRC"
else
  echo "${GREEN}✅ No obvious broken paths detected${NC}"
fi
echo ""

# Check directory structure
echo "${BLUE}📁 Directory structure:${NC}"
find . -maxdepth 2 -type d -not -path '*/\.*' 2>/dev/null | head -10 | sed 's|^\./||' | sed 's|^|  - |'
echo ""

echo "${GREEN}✅ Validation complete${NC}"
