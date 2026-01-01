#!/bin/bash
set -e

echo "🔧 Fixing static site (WordPress export)..."
echo ""

# Counters
REMOVED_FILES=0
MODIFIED_HTML=0

# ═══════════════════════════════════════════════════════════
# STEP 1: Remove legacy WordPress JavaScript files
# ═══════════════════════════════════════════════════════════

echo "📦 Step 1: Removing legacy WordPress JS files..."
echo "──────────────────────────────────────────────────"

# Files to remove (not needed in static site)
LEGACY_PATTERNS=(
  "*/autoptimize/*"
  "*/comment-reply*.js"
  "*/wp-embed*.js"
  "*/wp-emoji*.js"
)

for pattern in "${LEGACY_PATTERNS[@]}"; do
  FOUND=$(find . -path "*/.git" -prune -o -path "$pattern" -type f -print | wc -l)
  
  if [ "$FOUND" -gt 0 ]; then
    echo "  🗑️  Removing: $pattern ($FOUND files)"
    find . -path "*/.git" -prune -o -path "$pattern" -type f -print -delete
    REMOVED_FILES=$((REMOVED_FILES + FOUND))
  fi
done

if [ "$REMOVED_FILES" -eq 0 ]; then
  echo "  ✓ No legacy JS files found (already clean)"
else
  echo "  ✅ Removed $REMOVED_FILES legacy JS files"
fi

echo ""

# ═══════════════════════════════════════════════════════════
# STEP 2: Add click handler fix to HTML files
# ═══════════════════════════════════════════════════════════

echo "🖱️  Step 2: Fixing click handlers in HTML files..."
echo "──────────────────────────────────────────────────"

# Find all HTML files
HTML_FILES=$(find . -name "*.html" -type f ! -path '*/.git/*' ! -path '*/.github/*')
HTML_COUNT=$(echo "$HTML_FILES" | grep -c '.' || echo 0)

if [ "$HTML_COUNT" -eq 0 ]; then
  echo "  ⚠️  No HTML files found"
else
  echo "  Found $HTML_COUNT HTML files"
  echo ""
  
  # JavaScript fix to add before </body>
  read -r -d '' CLICK_FIX <<'JSEOF' || true
<!-- Static Site Navigation Fix -->
<script>
(function() {
  'use strict';
  
  // Kill all legacy WordPress event listeners on links
  document.addEventListener('click', function(e) {
    var target = e.target;
    
    // Find closest <a> tag
    while (target && target.tagName !== 'A') {
      target = target.parentElement;
      if (!target || target === document.body) return;
    }
    
    if (!target || !target.href) return;
    
    var url = target.href;
    var currentHost = window.location.hostname;
    
    try {
      var linkHost = new URL(url).hostname;
      
      // Only handle internal links with .html
      if (linkHost === currentHost && url.includes('.html')) {
        
        // Stop ALL other event handlers (WordPress legacy)
        e.stopImmediatePropagation();
        
        // Allow normal Ctrl/Cmd+Click (new tab)
        if (e.ctrlKey || e.metaKey || e.shiftKey || target.target === '_blank') {
          return true;
        }
        
        // Prevent default and navigate directly
        e.preventDefault();
        window.location.href = url;
        return false;
      }
    } catch (err) {
      // Invalid URL, let browser handle
      return true;
    }
  }, true); // true = capturing phase (FIRST handler)
  
})();
</script>
JSEOF
  
  # Process each HTML file
  for file in $HTML_FILES; do
    # Check if fix already exists (idempotent)
    if grep -q "Static Site Navigation Fix" "$file" 2>/dev/null; then
      echo "  ⏭️  Skip: $file (already fixed)"
      continue
    fi
    
    # Check if </body> exists
    if ! grep -q "</body>" "$file" 2>/dev/null; then
      echo "  ⚠️  Skip: $file (no </body> tag)"
      continue
    fi
    
    # Add fix before </body>
    # Use awk for reliable insertion
    awk -v fix="$CLICK_FIX" '
      /<\/body>/ {
        print fix
      }
      { print }
    ' "$file" > "$file.tmp"
    
    mv "$file.tmp" "$file"
    
    echo "  ✅ Fixed: $file"
    MODIFIED_HTML=$((MODIFIED_HTML + 1))
  done
  
  echo ""
  if [ "$MODIFIED_HTML" -eq 0 ]; then
    echo "  ✓ All HTML files already have the fix"
  else
    echo "  ✅ Added click handler fix to $MODIFIED_HTML files"
  fi
fi

echo ""

# ═══════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Static site fixes complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 Summary:"
echo "  - Removed JS files: $REMOVED_FILES"
echo "  - Fixed HTML files: $MODIFIED_HTML"
echo ""

if [ $((REMOVED_FILES + MODIFIED_HTML)) -gt 0 ]; then
  echo "✨ Static site is now optimized for GitHub Pages!"
else
  echo "ℹ️  Site was already optimized - no changes needed"
fi

exit 0
