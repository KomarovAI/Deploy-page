#!/usr/bin/env python3
"""Fix static site issues for WordPress exports."""

import sys
import re
from pathlib import Path
from typing import List, Tuple

try:
    from bs4 import BeautifulSoup
except ImportError:
    print("⚠️  BeautifulSoup4 not found, installing...")
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "beautifulsoup4", "lxml"])
    from bs4 import BeautifulSoup


class StaticSiteFixer:
    """WordPress static site fixer."""
    
    def __init__(self):
        self.files_removed = 0
        self.js_fixed = 0
        self.html_patched = 0
        self.artifacts_removed = 0
        
    def print_step(self, step: int, title: str):
        """Print formatted step header."""
        print(f"\n📦 Step {step}: {title}...")
        print("━" * 46)
    
    def remove_legacy_js(self):
        """Remove WordPress legacy JavaScript files."""
        self.print_step(1, "Removing legacy WordPress JavaScript")
        
        cwd = Path.cwd()
        
        # Remove Autoptimize cache
        autoptimize_dir = cwd / "wp-content" / "cache" / "autoptimize"
        if autoptimize_dir.exists():
            import shutil
            shutil.rmtree(autoptimize_dir)
            print("  ✓ Removed Autoptimize cache")
            self.files_removed += 1
        
        # Remove problematic JS files
        patterns = [
            "comment-reply*.js",
            "wp-embed*.js",
            "customize-*.js"
        ]
        
        for pattern in patterns:
            for file in cwd.rglob(pattern):
                if ".git" not in file.parts:
                    file.unlink()
                    if pattern.startswith("comment-reply"):
                        print(f"  ✓ Removed {pattern}")
                        self.files_removed += 1
        
        print(f"  📝 Total legacy files removed: {self.files_removed}")
    
    def check_theme_js(self):
        """Check theme JavaScript for navigation conflicts."""
        self.print_step(2, "Patching theme JavaScript")
        
        cwd = Path.cwd()
        theme_js_files = list(cwd.glob("wp-content/themes/*/assets/js/*.js"))
        theme_js_files = [f for f in theme_js_files if not f.name.endswith(".min.js")]
        
        if not theme_js_files:
            print("  ℹ️  No theme JavaScript files found to patch")
            return
        
        for js_file in theme_js_files:
            content = js_file.read_text(encoding="utf-8", errors="ignore")
            if "e.preventDefault()" in content:
                print(f"  ⚠️  Found preventDefault in: {js_file.name}")
                print("  → Manual review recommended for production")
                self.js_fixed += 1
        
        if self.js_fixed > 0:
            print(f"  📝 Theme JS files flagged: {self.js_fixed}")
        else:
            print("  ✓ No navigation conflicts found in theme JS")
    
    def inject_navigation_fix(self):
        """Inject click handler fix into HTML files."""
        self.print_step(3, "Injecting click handler fix")
        
        cwd = Path.cwd()
        html_files = [
            f for f in cwd.rglob("*.html")
            if ".git" not in f.parts and ".github" not in f.parts
        ]
        
        if not html_files:
            print("  ⚠️  No HTML files found")
            return
        
        print(f"  Processing {len(html_files)} HTML files...\n")
        
        # JavaScript fix to inject
        js_fix = """<!-- Static Site Navigation Fix -->
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
</script>"""
        
        for html_file in html_files:
            try:
                # Read file
                content = html_file.read_text(encoding="utf-8", errors="ignore")
                
                # Check if already patched (idempotent)
                if "Static Site Navigation Fix" in content:
                    print(f"  → {html_file.name}: already patched")
                    continue
                
                # Parse HTML
                soup = BeautifulSoup(content, "html.parser")
                body_tag = soup.find("body")
                
                if not body_tag:
                    print(f"  ⚠️  {html_file.name}: no <body> tag found")
                    continue
                
                # Create script tag
                script_tag = BeautifulSoup(js_fix, "html.parser")
                
                # Insert before </body>
                body_tag.append(script_tag)
                
                # Write back
                html_file.write_text(str(soup), encoding="utf-8")
                
                print(f"  ✓ {html_file.name}: navigation fix injected")
                self.html_patched += 1
                
            except Exception as e:
                print(f"  ❌ {html_file.name}: ERROR - {e}")
        
        print(f"\n  📝 HTML files patched: {self.html_patched} / {len(html_files)}")
    
    def cleanup_wordpress_artifacts(self):
        """Clean up WordPress admin artifacts."""
        self.print_step(4, "Cleaning WordPress artifacts")
        
        cwd = Path.cwd()
        
        # Remove wp-login files
        for file in cwd.rglob("wp-login*"):
            if ".git" not in file.parts:
                file.unlink()
        
        # Remove specific files
        artifacts = ["xmlrpc.php", "wp-cron.php"]
        for artifact in artifacts:
            file_path = cwd / artifact
            if file_path.exists():
                file_path.unlink()
                print(f"  ✓ Removed {artifact}")
                self.artifacts_removed += 1
        
        if self.artifacts_removed == 0:
            print("  ℹ️  No WordPress artifacts found to remove")
        else:
            print(f"  📝 WordPress artifacts removed: {self.artifacts_removed}")
    
    def print_summary(self):
        """Print execution summary."""
        print("\n✅ Static site fixes complete!")
        print("━" * 46)
        print("📊 Summary:")
        print(f"  • Legacy JS files removed: {self.files_removed}")
        print(f"  • Theme JS files flagged: {self.js_fixed}")
        print(f"  • HTML files patched: {self.html_patched}")
        print(f"  • WordPress artifacts removed: {self.artifacts_removed}")
        print("━" * 46)
        print()
        
        if self.html_patched > 0:
            print("✨ Navigation fixes applied - fast clicks should now work!")
        else:
            print("ℹ️  No HTML files were patched (already correct or no </body> tags)")
    
    def run(self):
        """Execute all fixing steps."""
        print("🔧 Fixing static site issues (WordPress exports)...")
        print()
        
        try:
            self.remove_legacy_js()
            self.check_theme_js()
            self.inject_navigation_fix()
            self.cleanup_wordpress_artifacts()
            self.print_summary()
            return 0
        except Exception as e:
            print(f"\n❌ FATAL ERROR: {e}")
            import traceback
            traceback.print_exc()
            return 1


if __name__ == "__main__":
    fixer = StaticSiteFixer()
    sys.exit(fixer.run())
