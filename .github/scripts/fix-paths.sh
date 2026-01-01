#!/usr/bin/env python3
"""Fix paths for GitHub Pages deployment."""

import os
import sys
import re
from pathlib import Path
from urllib.parse import urlparse, urlunparse, parse_qs, urlencode
from typing import Optional

try:
    from bs4 import BeautifulSoup
except ImportError:
    print("⚠️  BeautifulSoup4 not found, installing...")
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "beautifulsoup4", "lxml"])
    from bs4 import BeautifulSoup


class PathFixer:
    """Fix paths for GitHub Pages compatibility."""
    
    def __init__(self, base_href: str = "/"):
        self.base_href = base_href.rstrip("/")
        self.files_modified = 0
        self.total_changes = 0
        
    def should_add_html_extension(self, path: str) -> bool:
        """Check if path needs .html extension."""
        # Skip if already has extension
        filename = path.split('/')[-1].split('?')[0].split('#')[0]
        if '.' in filename:
            return False
        
        # Skip if empty or special
        if not path or path.startswith('http://') or path.startswith('https://') or path.startswith('//'):
            return False
        
        # Skip anchors only
        if path.startswith('#'):
            return False
        
        return True
    
    def fix_url(self, url: str, attr_type: str = "href") -> str:
        """Fix a single URL."""
        original_url = url
        
        # Parse URL
        parsed = urlparse(url)
        
        # Fix domain-absolute URLs
        if 'www.caterkitservices.com' in url:
            url = url.replace('https://www.caterkitservices.com/', './')
            url = url.replace('http://www.caterkitservices.com/', './')
            parsed = urlparse(url)
        
        # Fix root-relative paths
        if parsed.path.startswith('/') and not parsed.netloc:
            if self.base_href == "" or self.base_href == "/":
                # ROOT deployment: /path → ./path
                path = './' + parsed.path.lstrip('/')
            else:
                # SUBPATH deployment: /path → /base/path
                if not parsed.path.startswith(self.base_href + '/'):
                    path = self.base_href + parsed.path
                else:
                    path = parsed.path
            
            url = urlunparse((
                parsed.scheme,
                parsed.netloc,
                path,
                parsed.params,
                parsed.query,
                parsed.fragment
            ))
            parsed = urlparse(url)
        
        # Add .html extension for page links
        if attr_type == "href" and self.should_add_html_extension(parsed.path):
            # Split path from query/fragment
            path_parts = parsed.path.split('?', 1)
            base_path = path_parts[0].split('#', 1)[0]
            
            if not base_path.endswith('.html'):
                base_path += '.html'
                
                # Reconstruct URL
                url = urlunparse((
                    parsed.scheme,
                    parsed.netloc,
                    base_path,
                    parsed.params,
                    parsed.query,
                    parsed.fragment
                ))
        
        return url if url != original_url else original_url
    
    def fix_css_urls(self, css_content: str) -> str:
        """Fix url() in CSS."""
        def replace_url(match):
            url = match.group(1).strip('"\'')
            fixed_url = self.fix_url(url, attr_type="src")
            quote = '"' if '"' in match.group(0) else "'"
            return f"url({quote}{fixed_url}{quote})"
        
        # Match url(...) with various quote styles
        pattern = r'url\(["\']?([^"\')]+)["\']?\)'
        return re.sub(pattern, replace_url, css_content)
    
    def process_html_file(self, file_path: Path) -> int:
        """Process a single HTML file."""
        try:
            # Read file
            content = file_path.read_text(encoding="utf-8", errors="ignore")
            original_content = content
            
            # Parse HTML
            soup = BeautifulSoup(content, "html.parser")
            changes = 0
            
            # Fix href attributes
            for tag in soup.find_all(attrs={"href": True}):
                original_href = tag["href"]
                fixed_href = self.fix_url(original_href, attr_type="href")
                if fixed_href != original_href:
                    tag["href"] = fixed_href
                    changes += 1
            
            # Fix src attributes
            for tag in soup.find_all(attrs={"src": True}):
                original_src = tag["src"]
                fixed_src = self.fix_url(original_src, attr_type="src")
                if fixed_src != original_src:
                    tag["src"] = fixed_src
                    changes += 1
            
            # Fix CSS url() in <style> tags
            for style_tag in soup.find_all("style"):
                if style_tag.string:
                    original_css = style_tag.string
                    fixed_css = self.fix_css_urls(original_css)
                    if fixed_css != original_css:
                        style_tag.string.replace_with(fixed_css)
                        changes += 1
            
            # Fix inline style attributes
            for tag in soup.find_all(attrs={"style": True}):
                original_style = tag["style"]
                fixed_style = self.fix_css_urls(original_style)
                if fixed_style != original_style:
                    tag["style"] = fixed_style
                    changes += 1
            
            # Write back if changed
            if changes > 0:
                new_content = str(soup)
                file_path.write_text(new_content, encoding="utf-8")
                print(f"  ✓ {file_path.name}: {changes} changes")
                self.files_modified += 1
                self.total_changes += changes
            else:
                print(f"  → {file_path.name}: no changes needed")
            
            return changes
            
        except Exception as e:
            print(f"  ❌ {file_path.name}: ERROR - {e}")
            return 0
    
    def process_css_file(self, file_path: Path) -> int:
        """Process a single CSS file."""
        try:
            content = file_path.read_text(encoding="utf-8", errors="ignore")
            fixed_content = self.fix_css_urls(content)
            
            if fixed_content != content:
                file_path.write_text(fixed_content, encoding="utf-8")
                changes = content.count('url(') - fixed_content.count('url(') + 1
                print(f"  ✓ {file_path.name}: {changes} url() fixed")
                self.files_modified += 1
                self.total_changes += changes
                return changes
            else:
                print(f"  → {file_path.name}: no changes needed")
                return 0
                
        except Exception as e:
            print(f"  ❌ {file_path.name}: ERROR - {e}")
            return 0
    
    def run(self):
        """Execute path fixing."""
        print("🔧 Fixing paths for GitHub Pages...")
        print(f"BASE_HREF: {self.base_href if self.base_href else '/'}")
        print()
        
        cwd = Path.cwd()
        
        # Find HTML files
        html_files = [
            f for f in cwd.rglob("*.html")
            if ".git" not in f.parts and ".github" not in f.parts
        ]
        
        if not html_files:
            print("⚠️  No HTML files found, skipping path fixing")
            return 0
        
        print(f"Processing {len(html_files)} HTML files...\n")
        
        # Process HTML files
        for html_file in html_files:
            self.process_html_file(html_file)
        
        # Find and process CSS files
        css_files = [
            f for f in cwd.rglob("*.css")
            if ".git" not in f.parts and ".github" not in f.parts
        ]
        
        if css_files:
            print(f"\nProcessing {len(css_files)} CSS files...\n")
            for css_file in css_files:
                self.process_css_file(css_file)
        
        # Print summary
        print()
        print("✅ Path fixing complete!")
        print("━" * 32)
        print(f"Total files scanned: {len(html_files) + len(css_files)}")
        print(f"Files modified: {self.files_modified}")
        print(f"Total changes: {self.total_changes}")
        print("━" * 32)
        print()
        
        if self.files_modified == 0:
            print("ℹ️  All files were already correct - no changes needed")
        else:
            print(f"✨ Successfully updated {self.files_modified} file(s) for GitHub Pages")
        
        return 0


if __name__ == "__main__":
    # Read BASE_HREF from environment
    base_href = os.environ.get("BASE_HREF", "/")
    
    fixer = PathFixer(base_href=base_href)
    sys.exit(fixer.run())
