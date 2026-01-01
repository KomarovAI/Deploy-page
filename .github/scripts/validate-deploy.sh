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

# Validation mode: strict or soft
# Set STRICT_VALIDATION=true to fail on path issues
# Default: false (warnings only)
STRICT_VALIDATION="${STRICT_VALIDATION:-false}"

# Error counter
ERROR_COUNT=0
WARNING_COUNT=0

# Create detailed log file
LOG_FILE="/tmp/validation-$(date +%Y%m%d-%H%M%S).log"
echo "Validation started at $(date)" > "$LOG_FILE"
echo "Working directory: $(pwd)" >> "$LOG_FILE"
echo "Validation mode: $STRICT_VALIDATION" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

echo -e "${BLUE}📋 Log file: $LOG_FILE${NC}"
echo ""

# Check if we're in a directory with files
if [ ! -d "." ]; then
  echo -e "${RED}❌ No directory to validate${NC}"
  exit 1
fi

# Count files
TOTAL_FILES=$(find . -type f -not -path '*/.git/*' -not -path '*/.github/*' 2>/dev/null | wc -l)
HTML_FILES=$(find . -type f -name "*.html" 2>/dev/null | wc -l)
CSS_FILES=$(find . -type f -name "*.css" 2>/dev/null | wc -l)
JS_FILES=$(find . -type f -name "*.js" 2>/dev/null | wc -l)

echo -e "${BLUE}📊 File Statistics:${NC}"
echo "  • Total: $TOTAL_FILES files"
echo "  • HTML: $HTML_FILES files"
echo "  • CSS: $CSS_FILES files" 
echo "  • JS: $JS_FILES files"
echo ""

echo "File counts:" >> "$LOG_FILE"
echo "  Total: $TOTAL_FILES" >> "$LOG_FILE"
echo "  HTML: $HTML_FILES" >> "$LOG_FILE"
echo "  CSS: $CSS_FILES" >> "$LOG_FILE"
echo "  JS: $JS_FILES" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Check index.html
if [ -f "index.html" ]; then
  echo -e "${GREEN}✅ index.html found${NC}"
  SIZE=$(wc -c < "index.html")
  echo "   Size: $SIZE bytes"
  echo "index.html: $SIZE bytes" >> "$LOG_FILE"
  
  if [ "$SIZE" -lt 100 ]; then
    echo -e "${RED}❌ index.html is suspiciously small (<100 bytes)${NC}"
    echo "ERROR: index.html too small" >> "$LOG_FILE"
    ERROR_COUNT=$((ERROR_COUNT + 1))
  fi
else
  echo -e "${RED}❌ index.html not found${NC}"
  echo "ERROR: index.html missing" >> "$LOG_FILE"
  ERROR_COUNT=$((ERROR_COUNT + 1))
fi
echo ""

# Check for base href in subpath deployments
if [ -n "${BASE_HREF}" ] && [ "${BASE_HREF}" != "/" ]; then
  echo -e "${BLUE}🔍 Checking base href for subpath deployment...${NC}"
  echo "BASE_HREF check: ${BASE_HREF}" >> "$LOG_FILE"
  
  if grep -q '<base href' "index.html" 2>/dev/null; then
    BASE_HREF_VALUE=$(grep -o '<base href="[^"]*"' "index.html" | head -1 | sed 's/<base href="\([^"]*\)"/\1/')
    echo -e "${GREEN}✅ Base href found: ${BASE_HREF_VALUE}${NC}"
    echo "  Found: ${BASE_HREF_VALUE}" >> "$LOG_FILE"
    
    if [ "${BASE_HREF_VALUE}" != "${BASE_HREF}" ] && [ "${BASE_HREF_VALUE}" != "${BASE_HREF}/" ]; then
      echo -e "${YELLOW}⚠️  Warning: Base href mismatch (expected: ${BASE_HREF}, found: ${BASE_HREF_VALUE})${NC}"
      echo "  WARNING: mismatch" >> "$LOG_FILE"
      WARNING_COUNT=$((WARNING_COUNT + 1))
    fi
  else
    echo -e "${YELLOW}⚠️  Warning: Missing <base href> tag for subpath deployment${NC}"
    echo "  WARNING: <base href> missing" >> "$LOG_FILE"
    WARNING_COUNT=$((WARNING_COUNT + 1))
  fi
  echo ""
fi

# Python-based path validation (robust and accurate)
echo -e "${BLUE}🔗 Validating HTML paths with Python...${NC}"
echo "Path validation:" >> "$LOG_FILE"

python3 - <<'PYTHON_SCRIPT' 2>&1 | tee -a "$LOG_FILE"
import re
import sys
from pathlib import Path
import json

errors = []
warnings = []
detailed_issues = []

# Find all HTML files
html_files = list(Path('.').rglob('*.html'))

if not html_files:
    print("   ℹ️  No HTML files to validate")
    sys.exit(0)

print(f"   Scanning {len(html_files)} HTML files...")
print("")

# Check each file
for html_file in html_files:
    try:
        content = html_file.read_text(errors='ignore')
    except Exception as e:
        warnings.append(f"Could not read {html_file.name}: {e}")
        continue
    
    # Find problematic root-relative paths
    # Pattern: href="/something" or src="/something"
    # EXCLUDE: href="//domain.com", href="https://", href="http://", src="data:"
    
    # Find href="/path" (but NOT href="//external")
    bad_hrefs = re.findall(r'href="(/(?!/)[^"]*?)"', content)
    # Find src="/path" (but NOT src="//external" or src="data:")
    bad_srcs = re.findall(r'src="(/(?!/)[^"]*?)"', content)
    
    if bad_hrefs or bad_srcs:
        issue = {
            'file': str(html_file),
            'bad_hrefs': bad_hrefs[:10],  # Limit to first 10
            'bad_srcs': bad_srcs[:10]
        }
        detailed_issues.append(issue)
        
        if bad_hrefs:
            errors.append(f"{html_file.name}: {len(bad_hrefs)} root-relative href")
        if bad_srcs:
            errors.append(f"{html_file.name}: {len(bad_srcs)} root-relative src")

# Report results
if errors:
    print(f"⚠️  Found {len(errors)} file(s) with root-relative paths:")
    print("")
    
    for issue in detailed_issues:
        print(f"   📄 {issue['file']}:")
        
        if issue['bad_hrefs']:
            print(f"      🔗 {len(issue['bad_hrefs'])} href issues:")
            for href in issue['bad_hrefs'][:5]:  # Show first 5
                print(f"         - href=\"{href}\"")
            if len(issue['bad_hrefs']) > 5:
                print(f"         ... and {len(issue['bad_hrefs']) - 5} more")
        
        if issue['bad_srcs']:
            print(f"      🖼️  {len(issue['bad_srcs'])} src issues:")
            for src in issue['bad_srcs'][:5]:
                print(f"         - src=\"{src}\"")
            if len(issue['bad_srcs']) > 5:
                print(f"         ... and {len(issue['bad_srcs']) - 5} more")
        
        print("")
    
    # Save detailed report
    report_file = "/tmp/path-issues-detail.json"
    with open(report_file, 'w') as f:
        json.dump(detailed_issues, f, indent=2)
    print(f"   📊 Detailed report saved: {report_file}")
    print("")
    
    # Exit with error code
    sys.exit(1)
else:
    print("✅ All paths are relative or external URLs")
    print("   No root-relative paths detected")
    sys.exit(0)

PYTHON_SCRIPT

VALIDATION_RESULT=$?

if [ $VALIDATION_RESULT -ne 0 ]; then
  if [ "$STRICT_VALIDATION" = "true" ]; then
    echo -e "${RED}❌ Path validation FAILED (strict mode)${NC}"
    ERROR_COUNT=$((ERROR_COUNT + 1))
  else
    echo -e "${YELLOW}⚠️  Path validation issues detected (soft mode - continuing)${NC}"
    echo "  💡 Tip: Set STRICT_VALIDATION=true to fail on path issues"
    WARNING_COUNT=$((WARNING_COUNT + 1))
  fi
fi

echo ""

# Check directory structure
echo -e "${BLUE}📁 Directory structure (top level):${NC}"
echo "Top-level structure:" >> "$LOG_FILE"

find . -maxdepth 1 -type d -not -path '*/\.*' 2>/dev/null | sed 's|^\./||' | sed 's|^|  ├─ |' | tee -a "$LOG_FILE"
find . -maxdepth 1 -type f -not -path '*/\.*' 2>/dev/null | sed 's|^\./||' | sed 's|^|  ├─ |' | head -10 | tee -a "$LOG_FILE"

FILE_COUNT=$(find . -maxdepth 1 -type f -not -path '*/\.*' 2>/dev/null | wc -l)
if [ $FILE_COUNT -gt 10 ]; then
  echo "  └─ ... and $((FILE_COUNT - 10)) more files"
fi

echo ""

# Check for common asset directories
echo -e "${BLUE}📂 Asset directories:${NC}"
echo "Asset directories:" >> "$LOG_FILE"

FOUND_ASSETS=0
for dir in "assets" "css" "js" "images" "fonts" "static" "wp-content" "media"; do
  if [ -d "$dir" ]; then
    COUNT=$(find "$dir" -type f 2>/dev/null | wc -l)
    echo -e "${GREEN}  ✓ $dir/ ($COUNT files)${NC}"
    echo "  Found: $dir/ ($COUNT files)" >> "$LOG_FILE"
    FOUND_ASSETS=$((FOUND_ASSETS + 1))
  fi
done

if [ $FOUND_ASSETS -eq 0 ]; then
  echo "  ℹ️  No standard asset directories found (might be in subdirectories)"
fi

echo ""

# Final summary
echo "========================================"
echo "" >> "$LOG_FILE"
echo "Summary:" >> "$LOG_FILE"

if [ $ERROR_COUNT -gt 0 ]; then
  echo -e "${RED}❌ Validation FAILED${NC}"
  echo -e "${RED}   Errors: $ERROR_COUNT${NC}"
  echo -e "${YELLOW}   Warnings: $WARNING_COUNT${NC}"
  echo "FAILED - Errors: $ERROR_COUNT, Warnings: $WARNING_COUNT" >> "$LOG_FILE"
  echo ""
  echo -e "${BLUE}📝 Review detailed log: $LOG_FILE${NC}"
  exit 1
elif [ $WARNING_COUNT -gt 0 ]; then
  echo -e "${YELLOW}⚠️  Validation PASSED with warnings${NC}"
  echo -e "${YELLOW}   Warnings: $WARNING_COUNT${NC}"
  echo "PASSED with warnings: $WARNING_COUNT" >> "$LOG_FILE"
  
  if [ "$STRICT_VALIDATION" = "true" ]; then
    echo -e "${YELLOW}   (Would fail in strict mode)${NC}"
  fi
else
  echo -e "${GREEN}✅ Validation PASSED${NC}"
  echo -e "${GREEN}   No errors or warnings${NC}"
  echo "PASSED - No issues" >> "$LOG_FILE"
fi

echo ""
if [ -n "${BASE_HREF}" ] && [ "${BASE_HREF}" != "/" ]; then
  echo -e "${BLUE}ℹ️  Deployment: SUBPATH (${BASE_HREF})${NC}"
else
  echo -e "${BLUE}ℹ️  Deployment: ROOT (/)${NC}"
fi

echo -e "${BLUE}🔍 Validation mode: $([ \"$STRICT_VALIDATION\" = \"true\" ] && echo \"STRICT\" || echo \"SOFT\")${NC}"
echo ""
echo -e "${GREEN}✔️  Validation complete${NC}"

exit 0
