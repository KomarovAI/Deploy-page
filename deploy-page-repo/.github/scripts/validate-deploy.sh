#!/bin/bash

set -e

echo "Validating deployment..."
echo

# Count files
total_files=$(find . -type f | wc -l)
html_files=$(find . -name "*.html" | wc -l)
css_files=$(find . -name "*.css" | wc -l)

echo -e "\033[0;34m→ Files\033[0m"
echo "- Total: $total_files"
echo "- HTML: $html_files"
echo "- CSS: $css_files"
echo

# Check if index.html exists
if [ ! -f "index.html" ]; then
    echo -e "\033[0;31m✗ CRITICAL: index.html not found\033[0m"
    exit 1
fi

echo -e "\033[0;32m✓ index.html found\033[0m"
file_size=$(stat -f%z "index.html" 2>/dev/null || stat -c%s "index.html" 2>/dev/null)
echo "  Size: $file_size bytes"
echo

# Initialize counters
CRITICAL_ERRORS=0
WARNINGS=0

# Check for problematic paths in HTML files
echo -e "\033[0;34m→ Checking for problematic paths in HTML...\033[0m"

root_relative_count=0
double_slash_href_count=0
double_slash_src_count=0

for file in $(find . -name "*.html"); do
    # Count root-relative paths (excluding protocol URLs)
    root_relative=$(grep -oh 'href="/[^"]*"' "$file" | grep -v 'href="https\?://' | wc -l || echo 0)
    root_relative_count=$((root_relative_count + root_relative))
    
    # Count double slashes in paths (excluding protocol URLs like https://)
    # Fixed: Remove ^ anchor from grep -v pattern since grep -oh returns only match
    double_slash_href=$(grep -oh 'href="[^"]*//[^"]*"' "$file" | grep -v 'href="https\?://' | grep -v 'href="//' | wc -l || echo 0)
    double_slash_src=$(grep -oh 'src="[^"]*//[^"]*"' "$file" | grep -v 'src="https\?://' | grep -v 'src="//' | wc -l || echo 0)
    
    double_slash_href_count=$((double_slash_href_count + double_slash_href))
    double_slash_src_count=$((double_slash_src_count + double_slash_src))
done

if [ "$root_relative_count" -gt 0 ]; then
    echo -e "\033[0;31m✗ Root-relative paths detected: $root_relative_count\033[0m"
    CRITICAL_ERRORS=$((CRITICAL_ERRORS + 1))
else
    echo -e "\033[0;32m✓ No problematic root-relative paths detected\033[0m"
fi

if [ "$double_slash_href_count" -gt 0 ] || [ "$double_slash_src_count" -gt 0 ]; then
    echo -e "\033[0;31m✗ CRITICAL: Double slashes detected!\033[0m"
    [ "$double_slash_href_count" -gt 0 ] && echo "  - href with //: $double_slash_href_count"
    [ "$double_slash_src_count" -gt 0 ] && echo "  - src with //: $double_slash_src_count"
    echo -e "\033[0;31m✗ This indicates a bug in path fixing logic\033[0m"
    
    # Show examples
    echo "Examples:"
    for file in $(find . -name "*.html" | head -5); do
        grep -o 'href="[^"]*//[^"]*"' "$file" | grep -v 'https\?://' | grep -v '//' | head -3 || true
        grep -o 'src="[^"]*//[^"]*"' "$file" | grep -v 'https\?://' | grep -v '//' | head -3 || true
    done
    
    CRITICAL_ERRORS=$((CRITICAL_ERRORS + 1))
else
    echo -e "\033[0;32m✓ No double slashes in paths\033[0m"
fi

# Check for problematic paths in CSS files
echo
echo -e "\033[0;34m→ Checking for problematic paths in CSS...\033[0m"

if [ "$css_files" -eq 0 ]; then
    echo -e "\033[0;34m→ No CSS files to check\033[0m"
else
    css_url_count=0
    for file in $(find . -name "*.css"); do
        css_urls=$(grep -oh 'url(/[^)]*)' "$file" | grep -v 'url(https\?://' | wc -l || echo 0)
        css_url_count=$((css_url_count + css_urls))
    done
    
    if [ "$css_url_count" -gt 0 ]; then
        echo -e "\033[0;31m✗ Root-relative URLs in CSS: $css_url_count\033[0m"
        WARNINGS=$((WARNINGS + 1))
    else
        echo -e "\033[0;32m✓ No problematic CSS URLs\033[0m"
    fi
fi

# Check directory structure
echo
echo -e "\033[0;34m→ Directory structure (top level):\033[0m"
ls -1 | head -15 | sed 's/^/  - /'

# Check common asset directories
echo
echo -e "\033[0;34m→ Checking common asset directories...\033[0m"
for dir in wp-content wp-includes assets images js css; do
    if [ -d "$dir" ]; then
        count=$(find "$dir" -type f | wc -l)
        echo -e "\033[0;32m✓ $dir: $count files\033[0m"
    fi
done

# Check for specific services pages
echo
echo -e "\033[0;34m→ Checking category directories...\033[0m"
for dir in services sectors category news; do
    if [ -d "$dir" ]; then
        count=$(find "$dir" -name "*.html" | wc -l)
        echo -e "\033[0;32m✓ $dir: $count files\033[0m"
    fi
done

# Final summary
echo
if [ "$CRITICAL_ERRORS" -gt 0 ]; then
    echo -e "\033[0;31m✗ Validation FAILED\033[0m"
    echo -e "\033[0;31m✗ Errors: $CRITICAL_ERRORS\033[0m"
    [ "$WARNINGS" -gt 0 ] && echo -e "\033[1;33m⚠ Warnings: $WARNINGS\033[0m"
    echo
    echo -e "\033[0;31m✗ Critical issues must be fixed before deployment\033[0m"
    exit 1
else
    echo -e "\033[0;32m✓ Validation PASSED\033[0m"
    [ "$WARNINGS" -gt 0 ] && echo -e "\033[1;33m⚠ Warnings: $WARNINGS (non-critical)\033[0m"
    exit 0
fi
