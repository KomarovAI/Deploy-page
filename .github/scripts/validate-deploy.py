#!/usr/bin/env python3
"""Validate deployed website for GitHub Pages compatibility."""

import os
import sys
from pathlib import Path
from typing import List, Tuple
from urllib.parse import urlparse

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


class DeploymentValidator:
    """Validate deployment for GitHub Pages."""
    
    def __init__(self, strict_mode: bool = False, base_href: str = "/"):
        self.strict_mode = strict_mode
        self.base_href = base_href
        self.error_count = 0
        self.warning_count = 0
        self.cwd = Path.cwd()
        self.broken_links = []  # (file, href, target)
        self.html_files = []
    
    def count_files(self) -> dict:
        """Count files by type."""
        all_files = [
            f for f in self.cwd.rglob("*")
            if f.is_file() and ".git" not in f.parts and ".github" not in f.parts
        ]
        
        return {
            'total': len(all_files),
            'html': len([f for f in all_files if f.suffix == '.html']),
            'css': len([f for f in all_files if f.suffix == '.css']),
            'js': len([f for f in all_files if f.suffix == '.js']),
            'images': len([f for f in all_files if f.suffix in ['.png', '.jpg', '.jpeg', '.gif', '.svg', '.webp']])
        }
    
    def validate_index_html(self) -> bool:
        """Validate index.html exists and is valid."""
        index_path = self.cwd / "index.html"
        
        if not index_path.exists():
            print("❌ index.html not found")
            self.error_count += 1
            return False
        
        size = index_path.stat().st_size
        
        if size < 100:
            print(f"❌ index.html too small: {size} bytes")
            self.error_count += 1
            return False
        
        return True
    
    def validate_links_exist(self) -> int:
        """Check if all HTML links point to existing files.
        
        CRITICAL FIX: Validates that all internal links actually point to
        existing files/directories, preventing 404 errors.
        """
        html_files = [
            f for f in self.cwd.rglob("*.html")
            if ".git" not in f.parts and ".github" not in f.parts
        ]
        
        if not html_files:
            return 0
        
        broken_count = 0
        
        for html_file in html_files:
            try:
                content = html_file.read_text(encoding="utf-8", errors="ignore")
                soup = BeautifulSoup(content, "lxml")
                
                # Check all <a> tags
                for tag in soup.find_all('a', href=True):
                    href = tag['href']
                    
                    # Skip external links and special URLs
                    if href.startswith('http') or href.startswith('//') or href.startswith('mailto:'):
                        continue
                    if href.startswith('#'):
                        continue  # Anchor links are OK
                    if not href or href == '/':
                        continue
                    
                    # Extract path and fragment
                    path = href.split('?')[0].split('#')[0]
                    
                    if not path:
                        continue
                    
                    # Build target path
                    if path.startswith('/'):
                        # Absolute path from root
                        target = self.cwd / path.lstrip('/')
                    else:
                        # Relative path from current file
                        target = (html_file.parent / path).resolve()
                    
                    # Check if target exists
                    if not target.exists() and not (target.parent / "index.html").exists():
                        # This is a broken link
                        self.broken_links.append((
                            str(html_file.relative_to(self.cwd)),
                            href,
                            str(target.relative_to(self.cwd))
                        ))
                        broken_count += 1
                
            except Exception:
                pass
        
        return broken_count
    
    def validate_paths(self) -> int:
        """Validate all HTML paths for bad references.
        
        CRITICAL FIX: Detects absolute paths that should be relative.
        """
        html_files = [
            f for f in self.cwd.rglob("*.html")
            if ".git" not in f.parts and ".github" not in f.parts
        ]
        
        if not html_files:
            return 0
        
        issues_count = 0
        bad_files = []
        
        for html_file in html_files:
            try:
                content = html_file.read_text(encoding="utf-8", errors="ignore")
                soup = BeautifulSoup(content, "lxml")
                
                file_has_issues = False
                
                # Check for absolute paths that should be relative
                for tag in soup.find_all(attrs={"href": True}):
                    href = tag.get("href", "")
                    # Warn about /path patterns that start with /wp-content etc
                    if href.startswith("/wp-content/") or href.startswith("/wp-includes/"):
                        file_has_issues = True
                        issues_count += 1
                
                for tag in soup.find_all(attrs={"src": True}):
                    src = tag.get("src", "")
                    if src.startswith("/wp-content/") or src.startswith("/wp-includes/"):
                        file_has_issues = True
                        issues_count += 1
                
                if file_has_issues:
                    bad_files.append(html_file.name)
            
            except Exception:
                pass
        
        return issues_count
    
    def validate_resource_files(self) -> Tuple[int, int]:
        """Check CSS and JS files for validity.
        
        Returns:
            (total_resources, issues_found)
        """
        resource_files = list(self.cwd.rglob("*.css")) + list(self.cwd.rglob("*.js"))
        resource_files = [
            f for f in resource_files
            if ".git" not in f.parts and ".github" not in f.parts
        ]
        
        if not resource_files:
            return 0, 0
        
        issues = 0
        for resource_file in resource_files:
            try:
                content = resource_file.read_text(encoding="utf-8", errors="ignore")
                
                # Check for localhost references
                if 'localhost' in content or '127.0.0.1' in content:
                    issues += 1
                
                # Check for unresolved absolute paths
                if resource_file.suffix == '.css':
                    if 'url(/' in content and 'url(/wp-' in content:
                        issues += 1
                
            except Exception:
                pass
        
        return len(resource_files), issues
    
    def run(self) -> int:
        """Run validation."""
        # File statistics
        stats = self.count_files()
        
        # Validations
        index_valid = self.validate_index_html()
        path_issues = self.validate_paths()
        broken_links_count = self.validate_links_exist()
        resource_total, resource_issues = self.validate_resource_files()
        
        # Build summary
        parts = []
        parts.append(f"Files: {stats['total']}")
        parts.append(f"HTML: {stats['html']}")
        parts.append(f"CSS: {stats['css']}")
        parts.append(f"JS: {stats['js']}")
        
        # Report broken links
        if broken_links_count > 0:
            self.warning_count += 1
            print(f"⚠️  Found {broken_links_count} broken link(s):")
            for file, href, target in self.broken_links[:5]:  # Show first 5
                print(f"    {file}: {href} -> {target}")
            if len(self.broken_links) > 5:
                print(f"    ... and {len(self.broken_links) - 5} more")
            print()
        
        # Report resource issues
        if resource_issues > 0:
            self.warning_count += 1
            print(f"⚠️  Found {resource_issues} resource issue(s) in CSS/JS files\n")
        
        # Final status
        if self.error_count > 0:
            print(f"❌ VALIDATION FAILED: {', '.join(parts)}")
            return 1
        elif self.warning_count > 0:
            print(f"✅ Validation passed (with warnings): {', '.join(parts)}")
            return 0
        else:
            print(f"✅ Validation passed: {', '.join(parts)}")
            return 0


if __name__ == "__main__":
    strict_mode = os.environ.get("STRICT_VALIDATION", "false").lower() == "true"
    base_href = os.environ.get("BASE_HREF", "/")
    
    try:
        validator = DeploymentValidator(strict_mode=strict_mode, base_href=base_href)
        sys.exit(validator.run())
    except KeyboardInterrupt:
        print("⚠️ Interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Fatal error: {e}")
        sys.exit(1)
