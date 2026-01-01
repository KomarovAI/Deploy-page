#!/bin/bash
set -e

echo "🔧 Fixing static site issues (WordPress exports)..."
echo ""

# Counter for tracking operations
FILES_REMOVED=0
JS_FIXED=0
HTML_PATCHED=0

# =============================================================================
# STEP 1: Remove WordPress legacy JavaScript that breaks static sites
# =============================================================================
echo "📦 Step 1: Removing legacy WordPress JavaScript..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Remove Autoptimize cache (causes path conflicts)
if [ -d "wp-content/cache/autoptimize" ]; then
  rm -rf wp-content/cache/autoptimize
  echo "  ✓ Removed Autoptimize cache"
  FILES_REMOVED=$((FILES_REMOVED + 1))
fi

# Remove comment-reply.js (not needed on static sites)
find . -name "comment-reply*.js" -type f ! -path '*/.git/*' -delete 2>/dev/null || true
if [ $? -eq 0 ]; then
  echo "  ✓ Removed comment-reply.js"
  FILES_REMOVED=$((FILES_REMOVED + 1))
fi

# Remove other WordPress dynamic JS
find . -name "wp-embed*.js" -type f ! -path '*/.git/*' -delete 2>/dev/null || true
find . -name "customize-*.js" -type f ! -path '*/.git/*' -delete 2>/dev/null || true

echo "  📝 Total legacy files removed: $FILES_REMOVED"
echo ""

# =============================================================================
# STEP 2: Fix theme JavaScript that interferes with navigation
# =============================================================================
echo "📦 Step 2: Patching theme JavaScript..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Find all theme JS files (commonly in wp-content/themes/*/assets/js/)
THEME_JS_FILES=$(find . -path "*/wp-content/themes/*/assets/js/*.js" -type f ! -name "*.min.js" 2>/dev/null || echo "")

if [ -z "$THEME_JS_FILES" ]; then
  echo "  ℹ️  No theme JavaScript files found to patch"
else
  for js_file in $THEME_JS_FILES; do
    # Check if file contains preventDefault on links
    if grep -q "e.preventDefault()" "$js_file" 2>/dev/null; then
      echo "  ⚠️  Found preventDefault in: $js_file"
      echo "  → Manual review recommended for production"
      JS_FIXED=$((JS_FIXED + 1))
    fi
  done
  
  if [ $JS_FIXED -gt 0 ]; then
    echo "  📝 Theme JS files flagged: $JS_FIXED"
  else
    echo "  ✓ No navigation conflicts found in theme JS"
  fi
fi
echo ""

# =============================================================================
# STEP 3: Inject click handler fix into HTML files
# =============================================================================
echo "📦 Step 3: Injecting click handler fix..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Find all HTML files
HTML_FILES=$(find . -name "*.html" -type f ! -path '*/.git/*' ! -path '*/.github/*')
HTML_COUNT=$(echo "$HTML_FILES" | grep -c '.' || echo 0)

if [ "$HTML_COUNT" -eq 0 ]; then
  echo "  ⚠️  No HTML files found"
else
  echo "  Processing $HTML_COUNT HTML files..."
  echo ""
  
  # JavaScript fix to inject (stored in temp file for safe injection)
  JS_FIX_FILE=$(mktemp)
  cat > "$JS_FIX_FILE" << 'EOF'
<!-- Static Site Navigation Fix -->
<script>
(function() {
  'use strict';
  
  // Wait for DOM to be fully loaded
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initNavigationFix);
  } else {
    initNavigationFix();
  }
  
  function initNavigationFix() {
    // Override ALL click handlers on internal links
    document.addEventListener('click', function(e) {
      var target = e.target;
      var link = target.closest('a');
      
      if (!link) return;
      
      var href = link.getAttribute('href');
      if (!href) return;
      
      // Check if it's an internal .html link
      var isInternal = href.indexOf('.html') !== -1 && 
                       href.indexOf('://') === -1 && 
                       !href.startsWith('http') &&
                       href !== '#';
      
      if (isInternal) {
        // Stop ALL other event handlers (including legacy WordPress JS)
        e.stopImmediatePropagation();
        
        // Only prevent default if it's not a special click
        if (!e.ctrlKey && !e.metaKey && !e.shiftKey && e.button === 0) {
          e.preventDefault();
          
          // Simple, reliable navigation
          var fullHref = link.href || href;
          window.location.href = fullHref;
        }
      }
    }, true); // true = capturing phase (executes BEFORE other handlers)
    
    // Disable smooth scroll behaviors that might interfere
    if (window.history && window.history.scrollRestoration) {
      window.history.scrollRestoration = 'auto';
    }
  }
})();
</script>
EOF

  # Inject before </body> tag in each HTML file
  for file in $HTML_FILES; do
    # Check if file already has our fix (idempotent)
    if grep -q "Static Site Navigation Fix" "$file" 2>/dev/null; then
      echo "  → $(basename "$file"): already patched"
      continue
    fi
    
    # Check if file has </body> tag
    if grep -q "</body>" "$file" 2>/dev/null; then
      # Use perl for safe injection (handles special characters)
      perl -0777 -i -pe "s|</body>|\$(cat $JS_FIX_FILE)\n</body>|" "$file" 2>/dev/null || {
        # Fallback: use awk if perl fails
        awk -v insert="$(cat "$JS_FIX_FILE")" '
          /<\/body>/ { print insert }
          { print }
        ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
      }
      
      echo "  ✓ $(basename "$file"): navigation fix injected"
      HTML_PATCHED=$((HTML_PATCHED + 1))
    else
      echo "  ⚠️  $(basename "$file"): no </body> tag found"
    fi
  done
  
  # Cleanup temp file
  rm -f "$JS_FIX_FILE"
  
  echo ""
  echo "  📝 HTML files patched: $HTML_PATCHED / $HTML_COUNT"
fi
echo ""

# =============================================================================
# STEP 4: Clean up WordPress admin artifacts
# =============================================================================
echo "📦 Step 4: Cleaning WordPress artifacts..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

ARTIFACTS_REMOVED=0

# Remove wp-login.php references (not needed, causes 404s)
find . -name "wp-login*" -type f ! -path '*/.git/*' -delete 2>/dev/null || true

# Remove xmlrpc.php (security risk on static sites)
if [ -f "xmlrpc.php" ]; then
  rm -f xmlrpc.php
  echo "  ✓ Removed xmlrpc.php"
  ARTIFACTS_REMOVED=$((ARTIFACTS_REMOVED + 1))
fi

# Remove wp-cron.php (not functional on static sites)
if [ -f "wp-cron.php" ]; then
  rm -f wp-cron.php
  echo "  ✓ Removed wp-cron.php"
  ARTIFACTS_REMOVED=$((ARTIFACTS_REMOVED + 1))
fi

if [ $ARTIFACTS_REMOVED -eq 0 ]; then
  echo "  ℹ️  No WordPress artifacts found to remove"
else
  echo "  📝 WordPress artifacts removed: $ARTIFACTS_REMOVED"
fi
echo ""

# =============================================================================
# SUMMARY
# =============================================================================
echo "✅ Static site fixes complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Summary:"
echo "  • Legacy JS files removed: $FILES_REMOVED"
echo "  • Theme JS files flagged: $JS_FIXED"
echo "  • HTML files patched: $HTML_PATCHED"
echo "  • WordPress artifacts removed: $ARTIFACTS_REMOVED"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ $HTML_PATCHED -gt 0 ]; then
  echo "✨ Navigation fixes applied - fast clicks should now work!"
else
  echo "ℹ️  No HTML files were patched (already correct or no </body> tags)"
fi

exit 0
