#!/usr/bin/env python3
"""Validate deployed website for GitHub Pages compatibility."""

import os
import sys
from pathlib import Path
from typing import List

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
    
    def validate_paths(self) -> int:
        """Validate all HTML paths."""
        html_files = [
            f for f in self.cwd.rglob("*.html")
            if ".git" not in f.parts and ".github" not in f.parts
        ]
        
        if not html_files:
            return 0
        
        issues_count = 0
        
        for html_file in html_files:
            try:
                content = html_file.read_text(encoding="utf-8", errors="ignore")
                soup = BeautifulSoup(content, "lxml")
                
                bad_hrefs = []
                bad_srcs = []
                
                # Check href
                for tag in soup.find_all(attrs={"href": True}):
                    href = tag["href"]
                    if href.startswith("/") and not href.startswith("//"):
                        bad_hrefs.append(href)
                
                # Check src
                for tag in soup.find_all(attrs={"src": True}):
                    src = tag["src"]
                    if src.startswith("/") and not src.startswith(("/", "data:")):
                        bad_srcs.append(src)
                
                if bad_hrefs or bad_srcs:
                    issues_count += 1
            
            except Exception:
                pass
        
        if issues_count > 0:
            if self.strict_mode:
                self.error_count += 1
            else:
                self.warning_count += 1
        
        return issues_count
    
    def run(self) -> int:
        """Run validation with compact output."""
        # File statistics
        stats = self.count_files()
        
        # Validations
        index_valid = self.validate_index_html()
        path_issues = self.validate_paths()
        
        # Compact summary
        parts = []
        parts.append(f"Total: {stats['total']} files")
        parts.append(f"HTML: {stats['html']}")
        parts.append(f"JS: {stats['js']}")
        parts.append(f"Images: {stats['images']}")
        
        if self.error_count > 0:
            print(f"❌ VALIDATION FAILED: {', '.join(parts)}")
            return 1
        elif self.warning_count > 0:
            if path_issues > 0:
                print(f"⚠️ Validation passed: {', '.join(parts)} ({path_issues} path warnings)")
            else:
                print(f"✅ Validation passed: {', '.join(parts)}")
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
