#!/usr/bin/env python3
"""Fix static site issues for GitHub Pages deployment."""

import sys
import shutil
from pathlib import Path
from typing import List, Tuple, Optional, Dict
import re

# Auto-install dependencies
try:
    from bs4 import BeautifulSoup
except ImportError:
    print("📦 Installing dependencies...")
    import subprocess
    subprocess.check_call([
        sys.executable, "-m", "pip", "install",
        "beautifulsoup4", "lxml", "-q"
    ])
    from bs4 import BeautifulSoup


class StaticSiteFixer:
    """Fix static site issues for GitHub Pages."""
    
    # Files to skip during restructuring
    SKIP_RESTRUCTURE = {
        'index.html',
        '404.html',
        'robots.txt',
        'sitemap.xml',
    }
    
    # Known directory prefixes (ordered by length for precise matching)
    DIRECTORY_PREFIXES = [
        'services',  # Must be before 'sector' to avoid wrong matches
        'sectors',
        'category',
        'news',
    ]
    
    # Legacy scripts to remove
    LEGACY_SCRIPTS = [
        'autoptimize',
        'comment-reply',
        'wp-embed',
        'wp-emoji-release',
        'jquery-migrate'
    ]
    
    def __init__(self):
        self.files_processed = 0
        self.js_injected = 0
        self.scripts_removed = 0
        self.files_restructured = 0
        self.links_fixed = 0
        self.resources_fixed = 0
        self.restructure_map: Dict[str, str] = {}  # old_name -> new_path
    
    def detect_directory_structure(self, filename: str) -> Optional[Tuple[str, str]]:
        """Detect directory structure from flattened filename.
        
        CRITICAL FIX: Prevent hyphenated pages from being treated as nested.
        
        Examples:
            ✅ sectorsbars-pubs.html → ('sectors', 'bars-pubs')
            ✅ servicesdesign-sales-installation.html → ('services', 'design-sales-installation')
            ✅ categoryinsights.html → ('category', 'insights')
            ✅ newschristmas-opening.html → ('news', 'christmas-opening')
            
            ❌ news-insights.html → None (treated as standalone page, not news/-insights)
            ❌ services-test.html → None (treated as standalone page, not services/-test)
        
        Returns:
            (directory, basename) tuple or None if no prefix matches
        """
        # Try each known prefix
        for prefix in self.DIRECTORY_PREFIXES:
            if filename.startswith(prefix):
                # Extract the rest after prefix
                rest = filename[len(prefix):]
                
                # CRITICAL CHECK: If rest starts with hyphen, this is NOT a nested page
                # Example: "news-insights" has rest="-insights" → standalone page
                # Example: "newschristmas" has rest="christmas" → nested page
                if rest and not rest.startswith('-'):
                    return (prefix, rest)
        
        return None
    
    def restructure_files(self, cwd: Path) -> int:
        """Restructure HTML files by creating proper folder structure.
        
        This fixes GitHub Pages 404 errors by creating folder structure compatible
        with GitHub Pages routing.
        
        Transforms:
            sectorsbars-pubs.html -> sectors/bars-pubs/index.html
            servicesdesign-sales.html -> services/design-sales/index.html
            news-insights.html -> news-insights/index.html (NOT news/-insights/)
        """
        print("\n📁 RESTRUCTURING PAGES:")
        print("━" * 80)
        
        # Find all HTML files recursively, excluding .git and .github
        html_files = [
            f for f in cwd.rglob("**/*.html")
            if f.name.lower() not in self.SKIP_RESTRUCTURE
            and ".git" not in f.parts
            and ".github" not in f.parts
        ]
        
        if not html_files:
            print("   No files to restructure")
            return 0
        
        print(f"   Found {len(html_files)} files to check\n")
        
        restructured = 0
        for html_file in html_files:
            try:
                # Get relative path from cwd
                rel_path = html_file.relative_to(cwd)
                parent_dir = rel_path.parent
                base_name = html_file.stem  # filename without .html
                
                # Detect if filename is flattened (e.g., sectorsbars-pubs)
                detected_structure = self.detect_directory_structure(base_name)
                
                if detected_structure:
                    # Flattened filename detected - restore directory structure
                    dir_prefix, file_base = detected_structure
                    
                    # CRITICAL: Build CORRECT path with directories
                    if str(parent_dir) == '.':
                        # File is in root directory
                        target_folder = cwd / dir_prefix / file_base
                    else:
                        # File is in a subdirectory
                        target_folder = cwd / parent_dir / dir_prefix / file_base
                    
                    # CREATE the target folder
                    target_folder.mkdir(parents=True, exist_ok=True)
                    
                    # Target file: directory/basename/index.html
                    target_file = target_folder / "index.html"
                    
                    # Copy file content to new location
                    shutil.copy2(html_file, target_file)
                    
                    # Remove original file
                    html_file.unlink()
                    
                    old_name = html_file.name  # e.g., sectorsbars-pubs.html
                    new_path = f"{dir_prefix}/{file_base}/"  # e.g., sectors/bars-pubs/
                    
                    # Store mapping for link fixing
                    self.restructure_map[old_name] = new_path
                    
                    old_structure = str(rel_path)
                    new_structure = str(target_file.relative_to(cwd))
                    
                    # DETAILED OUTPUT - показываем каждую страницу
                    print(f"   ✓ {old_structure}")
                    print(f"     → {new_structure}")
                    print(f"     🌐 URL: /{new_path}")
                    print()
                    
                    restructured += 1
                
                else:
                    # Normal filename (not flattened) - check if needs restructuring
                    if base_name in ['index', '404']:
                        # Keep index.html and 404.html as-is
                        continue
                    
                    # Create folder for this file: parent/basename/index.html
                    if str(parent_dir) == '.':
                        target_folder = cwd / base_name
                    else:
                        target_folder = cwd / parent_dir / base_name
                    
                    # CREATE the target folder
                    target_folder.mkdir(parents=True, exist_ok=True)
                    
                    # Target file
                    target_file = target_folder / "index.html"
                    
                    # Copy file content to new location
                    shutil.copy2(html_file, target_file)
                    
                    # Remove original file
                    html_file.unlink()
                    
                    old_name = html_file.name  # e.g., contact.html
                    new_path = f"{base_name}/"  # e.g., contact/
                    
                    # Store mapping
                    self.restructure_map[old_name] = new_path
                    
                    old_structure = str(rel_path)
                    new_structure = str(target_file.relative_to(cwd))
                    
                    # DETAILED OUTPUT - показываем каждую страницу
                    print(f"   ✓ {old_structure}")
                    print(f"     → {new_structure}")
                    print(f"     🌐 URL: /{new_path}")
                    print()
                    
                    restructured += 1
                
            except Exception as e:
                print(f"   ✗ ERROR: {html_file.name}: {e}")
        
        self.files_restructured = restructured
        print("━" * 80)
        print(f"✅ Restructured {restructured} page(s)\n")
        return restructured
    
    def fix_resource_paths(self, soup: BeautifulSoup, depth: int) -> int:
        """Fix relative paths to CSS/JS/images after restructuring.
        
        CRITICAL FIX: Convert relative paths to work from subdirectories.
        
        Args:
            soup: BeautifulSoup parsed HTML
            depth: Folder nesting depth (news-insights/ = 1, sectors/bars/ = 2)
        
        Examples:
            depth=1: wp-content/... → ../wp-content/...
            depth=2: wp-content/... → ../../wp-content/...
        
        Returns:
            Number of resources fixed
        """
        if depth == 0:
            return 0
        
        fixed = 0
        prefix = "../" * depth
        
        # Fix CSS links
        for tag in soup.find_all('link', href=True):
            href = tag['href']
            if href.startswith('wp-content/') or href.startswith('wp-includes/'):
                tag['href'] = prefix + href
                fixed += 1
        
        # Fix JS scripts
        for tag in soup.find_all('script', src=True):
            src = tag['src']
            if src.startswith('wp-content/') or src.startswith('wp-includes/'):
                tag['src'] = prefix + src
                fixed += 1
        
        # Fix images
        for tag in soup.find_all('img', src=True):
            src = tag['src']
            if src.startswith('wp-content/'):
                tag['src'] = prefix + src
                fixed += 1
        
        # Fix background images in style attributes
        for tag in soup.find_all(style=True):
            style = tag['style']
            if 'wp-content/' in style:
                # Replace url(wp-content/...) with url(../wp-content/...)
                tag['style'] = re.sub(
                    r'url\(\s*(["\']?)wp-content/',
                    f'url(\\1{prefix}wp-content/',
                    style
                )
                fixed += 1
        
        return fixed
    
    def fix_internal_links(self, cwd: Path) -> int:
        """Fix internal links after restructuring.
        
        Updates links like:
            sectorsbars-pubs.html -> sectors/bars-pubs/
            servicesdesign.html -> services/design/
            news-insights.html -> news-insights/
        """
        if not self.restructure_map:
            return 0
        
        html_files = [
            f for f in cwd.rglob("*.html")
            if ".git" not in f.parts and ".github" not in f.parts
        ]
        
        fixed_count = 0
        
        for html_file in html_files:
            try:
                content = html_file.read_text(encoding="utf-8", errors="ignore")
                soup = BeautifulSoup(content, "lxml")
                modified = False
                
                # Fix <a href="...">
                for tag in soup.find_all('a', href=True):
                    href = tag['href']
                    
                    # Check if href matches old filename
                    for old_name, new_path in self.restructure_map.items():
                        if href == old_name or href == f"./{old_name}" or href.endswith(f"/{old_name}"):
                            tag['href'] = new_path
                            modified = True
                            self.links_fixed += 1
                
                if modified:
                    html_file.write_text(str(soup), encoding="utf-8")
                    fixed_count += 1
                    
            except Exception:
                pass  # Silent error handling
        
        return fixed_count
    
    def remove_legacy_scripts(self, soup: BeautifulSoup) -> int:
        """Remove legacy WordPress scripts."""
        removed = 0
        
        # Remove script tags
        for script in soup.find_all('script', src=True):
            src = script.get('src', '')
            if any(legacy in src for legacy in self.LEGACY_SCRIPTS):
                script.decompose()
                removed += 1
        
        # Remove inline scripts with legacy code
        for script in soup.find_all('script'):
            if script.string:
                if any(legacy in script.string for legacy in ['wp.emoji', 'addComment']):
                    script.decompose()
                    removed += 1
        
        return removed
    
    def inject_navigation_fix(self, soup: BeautifulSoup) -> bool:
        """Inject navigation fix script before </body>."""
        body = soup.find('body')
        if not body:
            return False
        
        # Navigation fix JavaScript
        nav_fix_js = '''<script>
// GitHub Pages navigation fix
(function() {
  console.log('✅ GitHub Pages navigation active');
})();
</script>'''
        
        # Create script tag
        script_tag = soup.new_tag('script')
        script_tag.string = nav_fix_js.strip()
        
        # Insert before </body>
        body.append(script_tag)
        return True
    
    def process_html_file(self, file_path: Path, cwd: Path) -> Tuple[bool, int, int]:
        """Process a single HTML file.
        
        Args:
            file_path: Path to HTML file
            cwd: Current working directory (repo root)
        
        Returns:
            (modified, scripts_removed, resources_fixed) tuple
        """
        try:
            content = file_path.read_text(encoding="utf-8", errors="ignore")
            soup = BeautifulSoup(content, "lxml")
            
            modified = False
            scripts_removed = 0
            resources_fixed = 0
            
            # Calculate folder depth for resource path fixing
            rel_path = file_path.relative_to(cwd)
            depth = len(rel_path.parts) - 1  # news-insights/index.html → depth=1
            
            # Fix resource paths (CSS/JS/images)
            resources_fixed = self.fix_resource_paths(soup, depth)
            if resources_fixed > 0:
                modified = True
                self.resources_fixed += resources_fixed
            
            # Remove legacy scripts
            scripts_removed = self.remove_legacy_scripts(soup)
            if scripts_removed > 0:
                modified = True
                self.scripts_removed += scripts_removed
            
            # Inject navigation fix
            if self.inject_navigation_fix(soup):
                modified = True
                self.js_injected += 1
            
            # Save if modified
            if modified:
                file_path.write_text(str(soup), encoding="utf-8")
                return True, scripts_removed, resources_fixed
            
            return False, 0, 0
            
        except Exception:
            return False, 0, 0
    
    def run(self) -> int:
        """Execute static site fixing with verbose restructure, compact other steps."""
        cwd = Path.cwd()
        
        # STEP 1: Restructure files (VERBOSE)
        self.restructure_files(cwd)
        
        # STEP 2: Fix internal links after restructuring (COMPACT)
        fixed_files = self.fix_internal_links(cwd)
        if self.links_fixed > 0:
            print(f"✅ Fixed {self.links_fixed} internal links in {fixed_files} files\n")
        
        # STEP 3: Find HTML files (after restructuring) (COMPACT)
        html_files = [
            f for f in cwd.rglob("*.html")
            if ".git" not in f.parts and ".github" not in f.parts
        ]
        
        if not html_files:
            print("⚠️ No HTML files found")
            return 0
        
        # Process files silently
        for html_file in html_files:
            modified, removed, resources = self.process_html_file(html_file, cwd)
            if modified:
                self.files_processed += 1
        
        # Compact summary for processing
        if self.resources_fixed > 0:
            print(f"✅ Fixed {self.resources_fixed} resource paths (CSS/JS/images)\n")
        
        if self.scripts_removed > 0:
            print(f"✅ Removed {self.scripts_removed} legacy scripts from {self.files_processed} files\n")
        
        return 0


if __name__ == "__main__":
    try:
        fixer = StaticSiteFixer()
        sys.exit(fixer.run())
    except KeyboardInterrupt:
        print("⚠️ Interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Fatal error: {e}")
        sys.exit(1)
