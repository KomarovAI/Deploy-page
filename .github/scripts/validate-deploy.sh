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

# Error counter
ERROR_COUNT=0
WARNING_COUNT=0

# Check if we're in a directory with files
if [ ! -d "." ]; then
  echo -e "${RED}❌ No directory to validate${NC}"
  exit 1
fi

# Count files
TOTAL_FILES=$(find . -type f -not -path '*/.git/*' -not -path '*/.github/*' 2>/dev/null | wc -l)
HTML_FILES=$(find . -type f -name "*.html" 2>/dev/null | wc -l)
CSS_FILES=$(find . -type f -name "*.css" 2>/dev/null | wc -l)
echo -e "${BLUE}📊 Files:${NC}"
echo "  - Total: $TOTAL_FILES"
echo "  - HTML: $HTML_FILES"
echo "  - CSS: $CSS_FILES"
echo ""

# Check index.html
if [ -f "index.html" ]; then
  echo -e "${GREEN}✅ index.html found${NC}"
  SIZE=$(wc -c < "index.html")
  echo "   Size: $SIZE bytes"
  
  if [ "$SIZE" -lt 100 ]; then
    echo -e "${RED}❌ index.html is suspiciously small${NC}"
    ERROR_COUNT=$((ERROR_COUNT + 1))
  fi
else
  echo -e "${RED}❌ index.html not found${NC}"
  ERROR_COUNT=$((ERROR_COUNT + 1))
fi
echo ""

# Check for base href in subpath deployments
if [ -n "${BASE_HREF}" ] && [ "${BASE_HREF}" != "/" ]; then
  echo -e "${BLUE}🔍 Checking base href for subpath deployment...${NC}"
  
  if grep -q '<base href' "index.html" 2>/dev/null; then
    BASE_HREF_VALUE=$(grep -o '<base href="[^"]*"' "index.html" | head -1 | sed 's/<base href="\([^"]*\)"/\1/')
    echo -e "${GREEN}✅ Base href found: ${BASE_HREF_VALUE}${NC}"
    
    if [ "${BASE_HREF_VALUE}" != "${BASE_HREF}" ] && [ "${BASE_HREF_VALUE}" != "${BASE_HREF}/" ]; then
      echo -e "${YELLOW}⚠️  Warning: Base href mismatch${NC}"
      WARNING_COUNT=$((WARNING_COUNT + 1))
    fi
  else
    echo -e "${YELLOW}⚠️  Warning: Missing <base href> tag${NC}"
    WARNING_COUNT=$((WARNING_COUNT + 1))
  fi
  echo ""
fi

# Python-based path validation (robust and accurate)
echo -e "${BLUE}🔗 Validating HTML paths with Python...${NC}"

python3 - <<'PYTHON_SCRIPT'
import re
import sys
from pathlib import Path

errors = []
warnings = []
examples = []

# Find all HTML files
html_files = list(Path('.').rglob('*.html'))

if not html_files:
    print("   No HTML files to validate")
    sys.exit(0)

# Check each file
for html_file in html_files:
    try:
        content = html_file.read_text(errors='ignore')
    except:
        continue
    
    # Find problematic root-relative paths
    # Pattern: href="/something" or src="/something"
    # EXCLUDE: href="//domain.com", href="https://", href="http://", src="data:"
    
    # Find href="/path" (but NOT href="//external")
    bad_hrefs = re.findall(r'href="(/(?!/)[^"]*)"', content)
    # Find src="/path" (but NOT src="//external" or src="data:")
    bad_srcs = re.findall(r'src="(/(?!/)[^"]*)"', content)
    
    if bad_hrefs:
        errors.append(f"{html_file.name}: {len(bad_hrefs)} root href")
        examples.extend(bad_hrefs[:2])
    
    if bad_srcs:
        errors.append(f"{html_file.name}: {len(bad_srcs)} root src")
        examples.extend(bad_srcs[:2])

# Report results
if errors:
    print(f"❌ Found {len(errors)} files with root-relative paths:")
    for err in errors[:10]:
        print(f"   {err}")
    
    if examples:
        print("\n   Examples:")
        for ex in examples[:5]:
            print(f"     {ex}")
    
    sys.exit(1)
else:
    print("✅ All paths are relative or external URLs")
    sys.exit(0)

PYTHON_SCRIPT

VALIDATION_RESULT=$?

if [ $VALIDATION_RESULT -ne 0 ]; then
  ERROR_COUNT=$((ERROR_COUNT + 1))
fi

echo ""

# Check directory structure
echo -e "${BLUE}📁 Directory structure (top level):${NC}"
find . -maxdepth 1 -type d -not -path '*/\.*' 2>/dev/null | sed 's|^\./||' | sed 's|^|  - |'
find . -maxdepth 1 -type f -not -path '*/\.*' 2>/dev/null | sed 's|^\./||' | sed 's|^|  - |' | head -5
echo ""

# Check for common asset directories
echo -e "${BLUE}📂 Asset directories:${NC}"
for dir in "assets" "css" "js" "images" "fonts" "static" "wp-content"; do
  if [ -d "$dir" ]; then
    COUNT=$(find "$dir" -type f 2>/dev/null | wc -l)
    echo -e "${GREEN}  ✓ $dir/ ($COUNT files)${NC}"
  fi
done
echo ""

# Final summary
echo "========================================"
if [ $ERROR_COUNT -gt 0 ]; then
  echo -e "${RED}❌ Validation FAILED${NC}"
  echo -e "${RED}   Errors: $ERROR_COUNT${NC}"
  echo -e "${YELLOW}   Warnings: $WARNING_COUNT${NC}"
  exit 1
elif [ $WARNING_COUNT -gt 0 ]; then
  echo -e "${YELLOW}⚠️  Validation PASSED with warnings${NC}"
  echo -e "${YELLOW}   Warnings: $WARNING_COUNT${NC}"
else
  echo -e "${GREEN}✅ Validation PASSED${NC}"
  echo -e "${GREEN}   No errors or warnings${NC}"
fi

echo ""
if [ -n "${BASE_HREF}" ] && [ "${BASE_HREF}" != "/" ]; then
  echo -e "${BLUE}ℹ️  Deployment: SUBPATH (${BASE_HREF})${NC}"
else
  echo -e "${BLUE}ℹ️  Deployment: ROOT (/)${NC}"
fi

exit 0
