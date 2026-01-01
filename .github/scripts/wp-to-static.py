#!/usr/bin/env python3
"""Radical WordPress to Static Site Converter.

Destroys WordPress structure, extracts content, builds clean static site.
"""

import sys
import shutil
import json
from pathlib import Path
from typing import Dict, List, Set, Optional
import re

# Auto-install dependencies
try:
    from bs4 import BeautifulSoup, Tag, NavigableString
except ImportError:
    print("📦 Installing dependencies...")
    import subprocess
    subprocess.check_call([
        sys.executable, "-m", "pip", "install",
        "beautifulsoup4", "lxml", "-q"
    ])
    from bs4 import BeautifulSoup, Tag, NavigableString


class WordPressDestroyer:
    """Completely removes WordPress, builds clean static site."""
    
    # GitHub Pages configuration
    BASE_PATH = "/archived-sites"
    
    # CRITICAL: Whitelist paths - ALWAYS KEEP
    WHITELIST_PATHS = [
        'wp-content/themes/',
        'wp-content/plugins/',
        'wp-content/uploads/'
    ]
    
    # WordPress garbage to remove
    WP_BLACKLIST = [
        'wp-includes/',
        'wp-admin/',
        'wp-block-library',
        'dashicons',
        'wp-emoji',
        'jquery-migrate',
        'autoptimize',
        'wp-polyfill',
        'regenerator-runtime',
        'comment-reply',
        'wp-embed'
    ]
    
    # Clean HTML template
    CLEAN_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{title}</title>
    {critical_css}
    {meta_tags}
</head>
<body>
    {content}
    {scripts}
</body>
</html>
"""
    
    def __init__(self):
        self.converted = 0
        self.cleaned_scripts = 0
        self.cleaned_styles = 0
        self.site_map: Dict[str, str] = {}  # old_path -> new_path
        self.css_files: Set[str] = set()
        self.js_files: Set[str] = set()
    
    def is_whitelisted(self, url: str) -> bool:
        """Check if resource is critical (theme/plugins)."""
        if not url:
            return False
        url_lower = url.lower()
        return any(path in url_lower for path in self.WHITELIST_PATHS)
    
    def is_blacklisted(self, url: str) -> bool:
        """Check if resource is WordPress garbage."""
        if not url:
            return False
        url_lower = url.lower()
        return any(wp in url_lower for wp in self.WP_BLACKLIST)
    
    def should_keep_resource(self, url: str) -> bool:
        """Decide if resource should be kept.
        
        Priority:
        1. External URLs -> skip
        2. Whitelist (themes/plugins) -> KEEP
        3. Blacklist (WP core) -> REMOVE
        4. Default -> keep (safe)
        """
        # Skip external
        if url.startswith(('http://', 'https://', '//')):
            return False
        
        # Whitelist first - critical resources
        if self.is_whitelisted(url):
            return True
        
        # Blacklist second - WP garbage
        if self.is_blacklisted(url):
            return False
        
        # Default: keep
        return True
    
    def extract_title(self, soup: BeautifulSoup) -> str:
        """Extract page title."""
        title_tag = soup.find('title')
        if title_tag and title_tag.string:
            title = title_tag.string.strip()
            title = re.sub(r'\s*[|–-]\s*.*$', '', title)
            return title
        return "Page"
    
    def extract_content(self, soup: BeautifulSoup) -> Optional[Tag]:
        """Extract main content."""
        selectors = [
            'main',
            '.entry-content',
            'article',
            '#content',
            '.site-content',
            'body'
        ]
        
        for selector in selectors:
            content = soup.select_one(selector)
            if content:
                content_copy = BeautifulSoup(str(content), 'lxml').find()
                for junk in content_copy.select('.wp-block-code, .sharedaddy, .jp-relatedposts'):
                    junk.decompose()
                return content_copy
        
        return None
    
    def collect_css(self, soup: BeautifulSoup, cwd: Path) -> List[str]:
        """Collect CSS with intelligent filtering."""
        css_files = []
        
        for link in soup.find_all('link', rel='stylesheet', href=True):
            href = link['href']
            
            # Apply smart filter
            if not self.should_keep_resource(href):
                if self.is_blacklisted(href):
                    self.cleaned_styles += 1
                continue
            
            # Normalize path
            css_path = href.lstrip('/')
            css_files.append(css_path)
            self.css_files.add(css_path)
        
        return css_files
    
    def collect_js(self, soup: BeautifulSoup) -> List[str]:
        """Collect JS with intelligent filtering."""
        js_files = []
        
        for script in soup.find_all('script', src=True):
            src = script['src']
            
            # Apply smart filter
            if not self.should_keep_resource(src):
                if self.is_blacklisted(src):
                    self.cleaned_scripts += 1
                continue
            
            # Normalize path
            js_path = src.lstrip('/')
            js_files.append(js_path)
            self.js_files.add(js_path)
        
        return js_files
    
    def fix_paths_in_content(self, content: Tag, base_path: str) -> None:
        """Fix all paths in extracted content."""
        # Fix images
        for img in content.find_all('img', src=True):
            src = img['src']
            if not src.startswith(('http://', 'https://', '//')):
                clean_src = src.lstrip('/')
                img['src'] = f"{base_path}/{clean_src}"
        
        # Fix links
        for a in content.find_all('a', href=True):
            href = a['href']
            
            if href.startswith(('http://', 'https://', '//', '#', 'mailto:', 'tel:')):
                continue
            
            clean_href = href.lstrip('./')
            
            if clean_href.endswith('.html'):
                page_name = clean_href[:-5]
                a['href'] = f"{base_path}/{page_name}/"
            elif not clean_href.endswith('/'):
                a['href'] = f"{base_path}/{clean_href}/"
            else:
                a['href'] = f"{base_path}/{clean_href}"
        
        # Fix background images in style
        for tag in content.find_all(style=True):
            style = tag['style']
            
            def replace_url(match):
                url = match.group(1).strip('"\'')
                if not url.startswith(('http://', 'https://', '//')):
                    clean_url = url.lstrip('/')
                    return f'url("{base_path}/{clean_url}")'
                return match.group(0)
            
            tag['style'] = re.sub(r'url\(([^)]+)\)', replace_url, style)
    
    def build_clean_html(self, title: str, content: Tag, css_files: List[str], js_files: List[str]) -> str:
        """Build clean HTML."""
        # CSS links
        css_links = []
        for css in css_files:
            css_links.append(f'    <link rel="stylesheet" href="{self.BASE_PATH}/{css}">')
        critical_css = '\n'.join(css_links) if css_links else ''
        
        # JS scripts
        js_scripts = []
        for js in js_files:
            js_scripts.append(f'    <script src="{self.BASE_PATH}/{js}" defer></script>')
        scripts = '\n'.join(js_scripts) if js_scripts else ''
        
        # Meta tags
        meta_tags = f'    <meta name="description" content="{title}">'
        
        # Build HTML
        html = self.CLEAN_TEMPLATE.format(
            title=title,
            critical_css=critical_css,
            meta_tags=meta_tags,
            content=str(content),
            scripts=scripts
        )
        
        return html
    
    def convert_file(self, html_file: Path, cwd: Path) -> bool:
        """Convert single WordPress HTML to clean static HTML."""
        try:
            content_raw = html_file.read_text(encoding='utf-8', errors='ignore')
            soup = BeautifulSoup(content_raw, 'lxml')
            
            title = self.extract_title(soup)
            content = self.extract_content(soup)
            
            if not content:
                print(f"   ⚠ No content: {html_file.name}")
                return False
            
            self.fix_paths_in_content(content, self.BASE_PATH)
            css_files = self.collect_css(soup, cwd)
            js_files = self.collect_js(soup)
            clean_html = self.build_clean_html(title, content, css_files, js_files)
            
            html_file.write_text(clean_html, encoding='utf-8')
            self.converted += 1
            return True
            
        except Exception as e:
            print(f"   ✗ Error {html_file.name}: {e}")
            return False
    
    def restructure_pages(self, cwd: Path) -> None:
        """Restructure flat HTML to directory structure."""
        print("\n📁 RESTRUCTURING:")
        print("═" * 80)
        
        html_files = [
            f for f in cwd.glob('*.html')
            if f.name not in ['index.html', '404.html']
        ]
        
        if not html_files:
            print("   No files to restructure\n")
            return
        
        restructured = 0
        for html_file in html_files:
            try:
                page_name = html_file.stem
                page_dir = cwd / page_name
                page_dir.mkdir(exist_ok=True)
                target = page_dir / 'index.html'
                shutil.move(str(html_file), str(target))
                print(f"   ✓ {html_file.name} → {page_name}/index.html")
                restructured += 1
                self.site_map[html_file.name] = f"{page_name}/"
            except Exception as e:
                print(f"   ✗ Error: {html_file.name}: {e}")
        
        print("═" * 80)
        print(f"✅ Restructured {restructured} pages\n")
    
    def create_404_page(self, cwd: Path) -> None:
        """Create 404 page if missing."""
        page_404 = cwd / '404.html'
        
        if page_404.exists():
            return
        
        html = self.CLEAN_TEMPLATE.format(
            title="404 - Page Not Found",
            critical_css='',
            meta_tags='',
            content='<main><h1>404 - Page Not Found</h1><p><a href="/archived-sites/">Go to Homepage</a></p></main>',
            scripts=''
        )
        
        page_404.write_text(html, encoding='utf-8')
        print("✅ Created 404.html\n")
    
    def run(self) -> int:
        """Execute WordPress destruction."""
        cwd = Path.cwd()
        
        print("\n🔥 WORDPRESS DESTROYER")
        print("═" * 80)
        print(f"Base path: {self.BASE_PATH}")
        print(f"Site URL: https://komarovai.github.io{self.BASE_PATH}/")
        print("═" * 80)
        
        html_files = [
            f for f in cwd.rglob('*.html')
            if '.git' not in f.parts and '.github' not in f.parts
        ]
        
        if not html_files:
            print("\n⚠️ No HTML files found")
            return 1
        
        print(f"\nFound {len(html_files)} HTML files\n")
        
        # Convert
        print("🧹 CONVERTING:")
        print("═" * 80)
        
        for html_file in html_files:
            if self.convert_file(html_file, cwd):
                rel_path = html_file.relative_to(cwd)
                print(f"   ✓ {rel_path}")
        
        print("═" * 80)
        print(f"✅ Converted {self.converted} files")
        print(f"🗑️  Removed {self.cleaned_scripts} WP scripts")
        print(f"🗑️  Removed {self.cleaned_styles} WP styles\n")
        
        # Restructure
        self.restructure_pages(cwd)
        
        # 404
        self.create_404_page(cwd)
        
        # Resources report
        print("📦 RESOURCES:")
        print("═" * 80)
        print(f"   CSS: {len(self.css_files)}")
        print(f"   JS: {len(self.js_files)}")
        
        if self.css_files:
            print("\n   CSS:")
            for css in sorted(self.css_files)[:5]:
                print(f"     - {css}")
            if len(self.css_files) > 5:
                print(f"     ... +{len(self.css_files) - 5} more")
        
        print("\n═" * 80)
        print("\n✅ WORDPRESS DESTROYED\n")
        
        return 0


if __name__ == '__main__':
    try:
        destroyer = WordPressDestroyer()
        sys.exit(destroyer.run())
    except KeyboardInterrupt:
        print("\n⚠️ Interrupted")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Fatal: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)