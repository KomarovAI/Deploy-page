#!/usr/bin/env python3
"""Fix paths for GitHub Pages deployment."""

import os
import sys
import re
from pathlib import Path
from urllib.parse import urlparse, urlunparse
from typing import Optional, List, Tuple

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


class PathFixer:
    """Fix paths for GitHub Pages compatibility."""
    
    def __init__(self, base_href: str = "/"):
        self.base_href = base_href.rstrip("/")
        self.files_modified = 0
        self.total_changes = 0
        
    def should_add_html_extension(self, path: str) -> bool:
        """Check if path needs .html extension.
        
        CRITICAL: Don't add .html to directory paths!
        
        Examples:
            /sectors/bars-pubs/ -> NO (directory path)
            /contact/ -> NO (directory path)
            /about -> YES (file without extension)
            /contact -> YES (file without extension)
        """
        # Remove query and fragment
        clean_path = path.split('?')[0].split('#')[0]
        
        # If ends with / it's a directory - NO .html
        if clean_path.endswith('/'):
            return False
        
        # Extract filename
        filename = clean_path.split('/')[-1]
        
        # If has extension - NO .html
        if '.' in filename:
            return False
        
        # External URLs - NO
        if path.startswith(('http://', 'https://', '//', '#')):
            return False
        
        # Empty path - NO
        if not path:
            return False
        
        # It's a file without extension - YES
        return True
    
    def fix_url(self, url: str, attr_type: str = "href") -> str:
        """Fix a single URL."""
        original_url = url
        parsed = urlparse(url)
        
        # Fix domain-absolute URLs
        if 'www.caterkitservices.com' in url:
            url = url.replace('https://www.caterkitservices.com/', './')
            url = url.replace('http://www.caterkitservices.com/', './')
            parsed = urlparse(url)
        
        # Fix root-relative paths
        if parsed.path.startswith('/') and not parsed.netloc:
            if self.base_href in ["", "/"]:
                path = './' + parsed.path.lstrip('/')
            else:
                path = self.base_href + parsed.path if not parsed.path.startswith(self.base_href + '/') else parsed.path
            
            url = urlunparse((
                parsed.scheme, parsed.netloc, path,
                parsed.params, parsed.query, parsed.fragment
            ))
            parsed = urlparse(url)
        
        # Add .html extension ONLY to files, NOT directories
        if attr_type == "href" and self.should_add_html_extension(parsed.path):
            base_path = parsed.path.split('?', 1)[0].split('#', 1)[0]
            
            if not base_path.endswith('.html'):
                base_path += '.html'
                url = urlunparse((
                    parsed.scheme, parsed.netloc, base_path,
                    parsed.params, parsed.query, parsed.fragment
                ))
        
        return url if url != original_url else original_url
    
    def fix_css_urls(self, css_content: str) -> str:
        """Fix url() in CSS."""
        def replace_url(match):
            url = match.group(1).strip('"\'')
            fixed_url = self.fix_url(url, attr_type="src")
            quote = '"' if '"' in match.group(0) else "'"
            return f"url({quote}{fixed_url}{quote})"
        
        pattern = r'url\(["\']?([^"\')]+)["\']?\)'
        return re.sub(pattern, replace_url, css_content)
    
    def process_html_file(self, file_path: Path) -> Tuple[int, bool]:
        """Process a single HTML file."""
        try:
            content = file_path.read_text(encoding="utf-8", errors="ignore")
            soup = BeautifulSoup(content, "lxml")  # lxml is FASTER!
            changes = 0
            
            # Fix href attributes
            for tag in soup.find_all(attrs={"href": True}):
                original = tag["href"]
                fixed = self.fix_url(original, attr_type="href")
                if fixed != original:
                    tag["href"] = fixed
                    changes += 1
            
            # Fix src attributes
            for tag in soup.find_all(attrs={"src": True}):
                original = tag["src"]
                fixed = self.fix_url(original, attr_type="src")
                if fixed != original:
                    tag["src"] = fixed
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
            
            if changes > 0:
                file_path.write_text(str(soup), encoding="utf-8")
                self.files_modified += 1
                self.total_changes += changes
                return changes, True
            
            return 0, False
            
        except Exception as e:
            print(f"❌ Error processing {file_path.name}: {e}")
            return 0, False
    
    def process_css_file(self, file_path: Path) -> Tuple[int, bool]:
        """Process a single CSS file."""
        try:
            content = file_path.read_text(encoding="utf-8", errors="ignore")
            fixed_content = self.fix_css_urls(content)
            
            if fixed_content != content:
                file_path.write_text(fixed_content, encoding="utf-8")
                changes = content.count('url(')
                self.files_modified += 1
                self.total_changes += changes
                return changes, True
            
            return 0, False
                
        except Exception as e:
            print(f"❌ Error processing {file_path.name}: {e}")
            return 0, False
    
    def run(self):
        """Execute path fixing with compact output."""
        cwd = Path.cwd()
        
        # Find files
        html_files = [
            f for f in cwd.rglob("*.html")
            if ".git" not in f.parts and ".github" not in f.parts
        ]
        
        css_files = [
            f for f in cwd.rglob("*.css")
            if ".git" not in f.parts and ".github" not in f.parts
        ]
        
        if not html_files and not css_files:
            print("⚠️ No HTML/CSS files found")
            return 0
        
        # Process files silently
        for html_file in html_files:
            self.process_html_file(html_file)
        
        for css_file in css_files:
            self.process_css_file(css_file)
        
        # Compact summary
        total_files = len(html_files) + len(css_files)
        
        if self.files_modified == 0:
            print(f"✅ Paths verified: {total_files} files (no changes needed)")
        else:
            print(f"✅ Paths fixed: {self.files_modified}/{total_files} files ({self.total_changes} changes)")
        
        return 0


if __name__ == "__main__":
    base_href = os.environ.get("BASE_HREF", "/")
    
    try:
        fixer = PathFixer(base_href=base_href)
        sys.exit(fixer.run())
    except KeyboardInterrupt:
        print("⚠️ Interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Fatal error: {e}")
        sys.exit(1)
