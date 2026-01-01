#!/usr/bin/env python3
"""Validate deployed website for GitHub Pages compatibility."""

import os
import sys
import json
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Tuple
import re

try:
    from bs4 import BeautifulSoup
except ImportError:
    print("⚠️  BeautifulSoup4 not found, installing...")
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "beautifulsoup4", "lxml"])
    from bs4 import BeautifulSoup


class Color:
    """ANSI color codes."""
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'  # No Color


class DeploymentValidator:
    """Validate deployment for GitHub Pages."""
    
    def __init__(self, strict_mode: bool = False, base_href: str = "/"):
        self.strict_mode = strict_mode
        self.base_href = base_href
        self.error_count = 0
        self.warning_count = 0
        self.cwd = Path.cwd()
        
        # Setup logging
        timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        self.log_file = Path(f"/tmp/validation-{timestamp}.log")
        self.log_lines = []
        
    def log(self, message: str, to_console: bool = True):
        """Log message to file and optionally console."""
        # Remove ANSI codes for log file
        clean_message = re.sub(r'\033\[[0-9;]+m', '', message)
        self.log_lines.append(clean_message)
        
        if to_console:
            print(message)
    
    def print_header(self, title: str):
        """Print colored header."""
        self.log(f"\n{Color.BLUE}{title}{Color.NC}")
    
    def count_files(self) -> Dict[str, int]:
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
            'images': len([f for f in all_files if f.suffix in ['.png', '.jpg', '.jpeg', '.gif', '.svg', '.webp']]),
        }
    
    def validate_index_html(self) -> bool:
        """Validate index.html exists and is valid."""
        index_path = self.cwd / "index.html"
        
        if not index_path.exists():
            self.log(f"{Color.RED}❌ index.html not found{Color.NC}")
            self.error_count += 1
            return False
        
        size = index_path.stat().st_size
        self.log(f"{Color.GREEN}✅ index.html found{Color.NC}")
        self.log(f"   Size: {size:,} bytes")
        
        if size < 100:
            self.log(f"{Color.RED}❌ index.html is suspiciously small (<100 bytes){Color.NC}")
            self.error_count += 1
            return False
        
        return True
    
    def validate_base_href(self) -> bool:
        """Validate base href for subpath deployments."""
        if self.base_href in ["/", ""]:
            return True
        
        self.print_header("🔍 Checking base href for subpath deployment...")
        
        index_path = self.cwd / "index.html"
        if not index_path.exists():
            return False
        
        content = index_path.read_text(encoding="utf-8", errors="ignore")
        soup = BeautifulSoup(content, "html.parser")
        
        base_tag = soup.find("base", attrs={"href": True})
        
        if not base_tag:
            self.log(f"{Color.YELLOW}⚠️  Warning: Missing <base href> tag for subpath deployment{Color.NC}")
            self.warning_count += 1
            return False
        
        found_href = base_tag["href"]
        self.log(f"{Color.GREEN}✅ Base href found: {found_href}{Color.NC}")
        
        # Allow trailing slash mismatch
        expected = [self.base_href, self.base_href + "/"]
        if found_href not in expected:
            self.log(f"{Color.YELLOW}⚠️  Warning: Base href mismatch (expected: {self.base_href}, found: {found_href}){Color.NC}")
            self.warning_count += 1
            return False
        
        return True
    
    def validate_paths(self) -> Tuple[bool, List[Dict]]:
        """Validate all HTML paths."""
        self.print_header("🔗 Validating HTML paths...")
        
        html_files = [
            f for f in self.cwd.rglob("*.html")
            if ".git" not in f.parts and ".github" not in f.parts
        ]
        
        if not html_files:
            self.log("   ℹ️  No HTML files to validate")
            return True, []
        
        self.log(f"   Scanning {len(html_files)} HTML files...\n")
        
        issues = []
        
        for html_file in html_files:
            try:
                content = html_file.read_text(encoding="utf-8", errors="ignore")
                soup = BeautifulSoup(content, "html.parser")
                
                bad_hrefs = []
                bad_srcs = []
                
                # Check href attributes
                for tag in soup.find_all(attrs={"href": True}):
                    href = tag["href"]
                    # Root-relative path: starts with / but NOT //
                    if href.startswith("/") and not href.startswith("//"):
                        bad_hrefs.append(href)
                
                # Check src attributes
                for tag in soup.find_all(attrs={"src": True}):
                    src = tag["src"]
                    # Root-relative path: starts with / but NOT // or data:
                    if src.startswith("/") and not src.startswith("//") and not src.startswith("data:"):
                        bad_srcs.append(src)
                
                if bad_hrefs or bad_srcs:
                    issues.append({
                        'file': str(html_file.relative_to(self.cwd)),
                        'bad_hrefs': bad_hrefs[:10],
                        'bad_srcs': bad_srcs[:10]
                    })
                    
            except Exception as e:
                self.log(f"{Color.YELLOW}⚠️  Could not parse {html_file.name}: {e}{Color.NC}")
                self.warning_count += 1
        
        if issues:
            self.log(f"{Color.YELLOW}⚠️  Found {len(issues)} file(s) with root-relative paths:{Color.NC}\n")
            
            for issue in issues:
                self.log(f"   📄 {issue['file']}:")
                
                if issue['bad_hrefs']:
                    self.log(f"      🔗 {len(issue['bad_hrefs'])} href issues:")
                    for href in issue['bad_hrefs'][:5]:
                        self.log(f"         - href=\"{href}\"")
                    if len(issue['bad_hrefs']) > 5:
                        self.log(f"         ... and {len(issue['bad_hrefs']) - 5} more")
                
                if issue['bad_srcs']:
                    self.log(f"      🖼️  {len(issue['bad_srcs'])} src issues:")
                    for src in issue['bad_srcs'][:5]:
                        self.log(f"         - src=\"{src}\"")
                    if len(issue['bad_srcs']) > 5:
                        self.log(f"         ... and {len(issue['bad_srcs']) - 5} more")
                
                self.log("")
            
            # Save detailed report
            report_file = Path("/tmp/path-issues-detail.json")
            report_file.write_text(json.dumps(issues, indent=2))
            self.log(f"   📊 Detailed report saved: {report_file}\n")
            
            if self.strict_mode:
                self.error_count += 1
                return False, issues
            else:
                self.warning_count += 1
                return True, issues
        else:
            self.log(f"{Color.GREEN}✅ All paths are relative or external URLs{Color.NC}")
            self.log("   No root-relative paths detected")
            return True, []
    
    def show_directory_structure(self):
        """Show top-level directory structure."""
        self.print_header("📁 Directory structure (top level):")
        
        items = sorted(self.cwd.iterdir(), key=lambda x: (not x.is_dir(), x.name))
        
        for item in items[:20]:
            if item.name.startswith('.'):
                continue
            
            if item.is_dir():
                file_count = len(list(item.rglob("*")))
                self.log(f"  ├─ {item.name}/ ({file_count} items)")
            else:
                size = item.stat().st_size
                self.log(f"  ├─ {item.name} ({size:,} bytes)")
        
        if len(items) > 20:
            self.log(f"  └─ ... and {len(items) - 20} more items")
    
    def check_asset_directories(self):
        """Check for common asset directories."""
        self.print_header("📂 Asset directories:")
        
        asset_dirs = ["assets", "css", "js", "images", "fonts", "static", "wp-content", "media"]
        found = 0
        
        for dir_name in asset_dirs:
            dir_path = self.cwd / dir_name
            if dir_path.exists() and dir_path.is_dir():
                file_count = len(list(dir_path.rglob("*")))
                self.log(f"{Color.GREEN}  ✓ {dir_name}/ ({file_count} files){Color.NC}")
                found += 1
        
        if found == 0:
            self.log("  ℹ️  No standard asset directories found (might be in subdirectories)")
    
    def print_summary(self):
        """Print validation summary."""
        self.log("\n" + "=" * 40)
        
        if self.error_count > 0:
            self.log(f"{Color.RED}❌ Validation FAILED{Color.NC}")
            self.log(f"{Color.RED}   Errors: {self.error_count}{Color.NC}")
            self.log(f"{Color.YELLOW}   Warnings: {self.warning_count}{Color.NC}")
        elif self.warning_count > 0:
            self.log(f"{Color.YELLOW}⚠️  Validation PASSED with warnings{Color.NC}")
            self.log(f"{Color.YELLOW}   Warnings: {self.warning_count}{Color.NC}")
            if self.strict_mode:
                self.log(f"{Color.YELLOW}   (Would fail in strict mode){Color.NC}")
        else:
            self.log(f"{Color.GREEN}✅ Validation PASSED{Color.NC}")
            self.log(f"{Color.GREEN}   No errors or warnings{Color.NC}")
        
        self.log("")
        
        if self.base_href and self.base_href != "/":
            self.log(f"{Color.BLUE}ℹ️  Deployment: SUBPATH ({self.base_href}){Color.NC}")
        else:
            self.log(f"{Color.BLUE}ℹ️  Deployment: ROOT (/){Color.NC}")
        
        mode = "STRICT" if self.strict_mode else "SOFT"
        self.log(f"{Color.BLUE}🔍 Validation mode: {mode}{Color.NC}")
        self.log(f"{Color.BLUE}📝 Log file: {self.log_file}{Color.NC}")
        
        self.log(f"\n{Color.GREEN}✔️  Validation complete{Color.NC}")
    
    def save_log(self):
        """Save log to file."""
        self.log_file.write_text("\n".join(self.log_lines))
    
    def run(self) -> int:
        """Run validation."""
        self.log("🔍 Validating deployment...\n")
        
        # Log metadata
        self.log(f"Validation started at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}", to_console=False)
        self.log(f"Working directory: {self.cwd}", to_console=False)
        self.log(f"Validation mode: {'STRICT' if self.strict_mode else 'SOFT'}", to_console=False)
        self.log("", to_console=False)
        
        # File statistics
        self.print_header("📊 File Statistics:")
        file_counts = self.count_files()
        self.log(f"  • Total: {file_counts['total']} files")
        self.log(f"  • HTML: {file_counts['html']} files")
        self.log(f"  • CSS: {file_counts['css']} files")
        self.log(f"  • JS: {file_counts['js']} files")
        self.log(f"  • Images: {file_counts['images']} files")
        self.log("")
        
        # Run validations
        self.validate_index_html()
        self.log("")
        
        self.validate_base_href()
        self.log("")
        
        self.validate_paths()
        self.log("")
        
        self.show_directory_structure()
        self.log("")
        
        self.check_asset_directories()
        
        # Summary
        self.print_summary()
        
        # Save log
        self.save_log()
        
        # Return exit code
        return 1 if self.error_count > 0 else 0


if __name__ == "__main__":
    # Read environment variables
    strict_mode = os.environ.get("STRICT_VALIDATION", "false").lower() == "true"
    base_href = os.environ.get("BASE_HREF", "/")
    
    validator = DeploymentValidator(strict_mode=strict_mode, base_href=base_href)
    sys.exit(validator.run())
