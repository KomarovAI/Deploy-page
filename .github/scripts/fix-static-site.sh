#!/usr/bin/env python3
"""
Fix static site for GitHub Pages + WordPress cleanup
"""
import os, sys, re
from pathlib import Path
from bs4 import BeautifulSoup
from collections import defaultdict

try:
    from rich.console import Console
    from rich.table import Table
except ImportError:
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "beautifulsoup4", "lxml", "rich", "-q"])
    from rich.console import Console
    from rich.table import Table

console = Console()

class StaticSiteFixer:
    WP_PATTERNS = [
        # Critical
        r'wp-admin', r'wp-login', r'wp-json', r'admin-ajax',
        r'wp-includes.*\.js', r'wp-includes.*\.css',
        r'comment-reply', r'wp-content/plugins', r'wp-content/themes',
        # Forms
        r'contact-form-7|wpcf7', r'jetpack',
        # jQuery
        r'jquery-migrate',
        # Analytics/Tracking
        r'googletagmanager', r'fbevents', r'stats\.wp\.com',
        # Extra
        r'gravatar', r'emoji', r'api\.w\.org',
    ]
    
    def __init__(self):
        self.files_processed = 0
        self.changes_made = 0
        self.wp_removed = 0
        self.base_tags_added = 0
    
    def clean_wordpress(self, soup: BeautifulSoup) -> int:
        """Remove all WordPress artifacts"""
        removed = 0
        
        # Remove scripts/links with WP patterns
        for tag in soup.find_all(['script', 'link']):
            src = (tag.get('src') or tag.get('href') or '').lower()
            for pattern in self.WP_PATTERNS:
                if re.search(pattern, src, re.I):
                    tag.decompose()
                    removed += 1
                    break
        
        # Remove WordPress meta tags
        for meta in soup.find_all('meta'):
            name = (meta.get('name') or '').lower()
            rel = (meta.get('rel') or '')
            if name == 'generator' or 'api.w.org' in str(rel):
                meta.decompose()
                removed += 1
        
        # Remove prefetch/dns-prefetch
        for link in soup.find_all('link', rel=['prefetch', 'dns-prefetch']):
            link.decompose()
            removed += 1
        
        # Remove IE conditional comments
        for comment in soup.find_all(string=lambda text: isinstance(text, str) and '[if IE' in text):
            comment.extract()
            removed += 1
        
        return removed
    
    def inject_base_tag(self, soup: BeautifulSoup, base_href: str = "/") -> bool:
        """Inject <base href> tag if missing"""
        head = soup.find('head')
        if not head:
            return False
        if head.find('base'):
            return False
        
        base_tag = soup.new_tag('base', href=base_href)
        charset = head.find('meta', charset=True)
        if charset:
            charset.insert_after(base_tag)
        else:
            head.insert(0, base_tag)
        
        self.base_tags_added += 1
        return True
    
    def process(self, site_path: str, base_href: str = "/"):
        """Process all HTML files"""
        site_path = Path(site_path)
        
        for html_file in sorted(site_path.rglob("*.html")):
            try:
                with open(html_file, 'r', encoding='utf-8', errors='ignore') as f:
                    soup = BeautifulSoup(f.read(), 'lxml')
                
                initial = str(soup)
                
                # Clean WP artifacts
                wp_removed = self.clean_wordpress(soup)
                self.wp_removed += wp_removed
                
                # Inject base tag
                self.inject_base_tag(soup, base_href)
                
                if str(soup) != initial:
                    with open(html_file, 'w', encoding='utf-8') as f:
                        f.write(str(soup))
                    self.changes_made += 1
                
                self.files_processed += 1
            except Exception as e:
                console.print(f"\u26a0️  {html_file}: {e}", style="yellow")
    
    def report(self):
        """Print summary"""
        table = Table(title="\ud83d\udcca Summary")
        table.add_column("Metric", style="cyan")
        table.add_column("Value", style="green")
        table.add_row("Files processed", str(self.files_processed))
        table.add_row("Files modified", str(self.changes_made))
        table.add_row("WP artifacts removed", str(self.wp_removed))
        table.add_row("<base> tags added", str(self.base_tags_added))
        console.print(table)

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 fix-static-site.py <site_path> [base_href]")
        sys.exit(1)
    
    site_path = sys.argv[1]
    base_href = sys.argv[2] if len(sys.argv) > 2 else "/"
    
    if not Path(site_path).exists():
        print(f"\u274c Path not found: {site_path}")
        sys.exit(1)
    
    console.print(f"\n\ud83d\udd27 Fixing static site: {site_path}", style="bold")
    console.print(f"\ud83d\udccc Base href: {base_href}\n")
    
    fixer = StaticSiteFixer()
    fixer.process(site_path, base_href)
    fixer.report()
    
    if fixer.changes_made > 0:
        console.print(f"\n\u2705 Updated {fixer.changes_made} file(s)!\n", style="green")
    else:
        console.print("\n\u2728 No changes needed!\n", style="green")

if __name__ == '__main__':
    main()
