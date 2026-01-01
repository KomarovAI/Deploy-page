#!/usr/bin/env python3
"""WordPress to Static Site Converter."""

import sys
import os
import shutil
from pathlib import Path
from typing import Dict, List, Set, Optional
import re

try:
    from bs4 import BeautifulSoup, Tag
except ImportError:
    import subprocess
    print("📦 Installing dependencies...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "beautifulsoup4", "lxml", "-q"])
    from bs4 import BeautifulSoup, Tag


class WordPressDestroyer:
    WHITELIST_PATHS = ['wp-content/themes/', 'wp-content/plugins/', 'wp-content/uploads/']
    WP_BLACKLIST = [
        'wp-includes/', 'wp-admin/', 'wp-block-library', 'dashicons',
        'wp-emoji', 'jquery-migrate', 'autoptimize', 'wp-polyfill',
        'regenerator-runtime', 'comment-reply', 'wp-embed'
    ]
    
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
    
    def __init__(self, base_path: str = "/", original_domain: str = ""):
        self.base_path = base_path.rstrip('/')
        self.original_domain = original_domain.rstrip('/')
        self.converted = 0
        self.cleaned_scripts = 0
        self.cleaned_styles = 0
        self.converted_absolute_urls = 0
        self.css_files: Set[str] = set()
        self.js_files: Set[str] = set()
    
    def is_whitelisted(self, url: str) -> bool:
        if not url:
            return False
        url_lower = url.lower()
        return any(path in url_lower for path in self.WHITELIST_PATHS)
    
    def is_blacklisted(self, url: str) -> bool:
        if not url:
            return False
        url_lower = url.lower()
        return any(wp in url_lower for wp in self.WP_BLACKLIST)
    
    def should_keep_resource(self, url: str) -> bool:
        if url.startswith(('http://', 'https://', '//')):
            return False
        if self.is_whitelisted(url):
            return True
        if self.is_blacklisted(url):
            return False
        return True
    
    def extract_title(self, soup: BeautifulSoup) -> str:
        title_tag = soup.find('title')
        if title_tag and title_tag.string:
            title = title_tag.string.strip()
            title = re.sub(r'\s*[|–-]\s*.*$', '', title)
            return title
        return "Page"
    
    def extract_content(self, soup: BeautifulSoup) -> Optional[Tag]:
        selectors = ['main', '.entry-content', 'article', '#content', '.site-content', 'body']
        for selector in selectors:
            content = soup.select_one(selector)
            if content:
                content_copy = BeautifulSoup(str(content), 'lxml').find()
                for junk in content_copy.select('.wp-block-code, .sharedaddy, .jp-relatedposts'):
                    junk.decompose()
                return content_copy
        return None
    
    def collect_css(self, soup: BeautifulSoup) -> List[str]:
        css_files = []
        for link in soup.find_all('link', rel='stylesheet', href=True):
            href = link['href']
            if not self.should_keep_resource(href):
                if self.is_blacklisted(href):
                    self.cleaned_styles += 1
                continue
            css_path = href.lstrip('/')
            css_files.append(css_path)
            self.css_files.add(css_path)
        return css_files
    
    def collect_js(self, soup: BeautifulSoup) -> List[str]:
        js_files = []
        for script in soup.find_all('script', src=True):
            src = script['src']
            if not self.should_keep_resource(src):
                if self.is_blacklisted(src):
                    self.cleaned_scripts += 1
                continue
            js_path = src.lstrip('/')
            js_files.append(js_path)
            self.js_files.add(js_path)
        return js_files
    
    def fix_url(self, url: str) -> str:
        """Fix single URL with anchor support and original domain conversion."""
        if not url:
            return url
        
        # Skip special protocols
        if url.startswith(('#', 'mailto:', 'tel:', 'javascript:', 'data:')):
            return url
        
        original_url = url
        
        # Convert absolute URLs from original domain to relative
        if self.original_domain and url.startswith(('http://', 'https://', '//')):
            # Normalize protocol-relative URLs
            if url.startswith('//'):
                url = 'https:' + url
            
            # Check if URL belongs to original domain
            domain_variants = [
                self.original_domain,
                self.original_domain.replace('https://', 'http://'),
                self.original_domain.replace('http://', 'https://'),
                self.original_domain.replace('https://', '//'),
                self.original_domain.replace('http://', '//')
            ]
            
            for domain in domain_variants:
                if url.startswith(domain):
                    # Remove domain, keep path
                    url = url[len(domain):]
                    if not url.startswith('/'):
                        url = '/' + url
                    self.converted_absolute_urls += 1
                    break
            else:
                # External domain - keep as is
                return original_url
        
        # Skip external URLs
        if url.startswith(('http://', 'https://', '//')):
            return url
        
        # Split anchor
        anchor = ''
        if '#' in url:
            url, anchor = url.split('#', 1)
            anchor = '#' + anchor
        
        # Split query
        query = ''
        if '?' in url:
            url, query = url.split('?', 1)
            query = '?' + query
        
        clean_url = url.lstrip('./')
        
        # Add .html if needed
        if clean_url and not clean_url.endswith(('.html', '/')):
            if '.' not in clean_url.split('/')[-1]:
                clean_url += '.html'
        
        # Build final URL
        result = f"{self.base_path}/{clean_url}" if self.base_path != '/' else f"/{clean_url}"
        return result + query + anchor
    
    def fix_paths_in_content(self, content: Tag) -> None:
        # Fix images
        for img in content.find_all('img', src=True):
            img['src'] = self.fix_url(img['src'])
        
        # Fix data-src/data-bg
        for tag in content.find_all(attrs={'data-src': True}):
            tag['data-src'] = self.fix_url(tag['data-src'])
        for tag in content.find_all(attrs={'data-bg': True}):
            tag['data-bg'] = self.fix_url(tag['data-bg'])
        for tag in content.find_all(attrs={'data-background': True}):
            tag['data-background'] = self.fix_url(tag['data-background'])
        
        # Fix links
        for a in content.find_all('a', href=True):
            a['href'] = self.fix_url(a['href'])
        
        # Fix style backgrounds
        for tag in content.find_all(style=True):
            style = tag['style']
            def replace_url(match):
                url = match.group(1).strip('"\'')
                fixed = self.fix_url(url)
                return f'url("{fixed}")'
            tag['style'] = re.sub(r'url\(([^)]+)\)', replace_url, style)
    
    def build_clean_html(self, title: str, content: Tag, css_files: List[str], js_files: List[str]) -> str:
        css_links = [f'    <link rel="stylesheet" href="{self.base_path}/{css}">' for css in css_files]
        critical_css = '\n'.join(css_links) if css_links else ''
        
        js_scripts = [f'    <script src="{self.base_path}/{js}" defer></script>' for js in js_files]
        scripts = '\n'.join(js_scripts) if js_scripts else ''
        
        meta_tags = f'    <meta name="description" content="{title}">'
        
        return self.CLEAN_TEMPLATE.format(
            title=title,
            critical_css=critical_css,
            meta_tags=meta_tags,
            content=str(content),
            scripts=scripts
        )
    
    def convert_file(self, html_file: Path) -> bool:
        try:
            content_raw = html_file.read_text(encoding='utf-8', errors='ignore')
            soup = BeautifulSoup(content_raw, 'lxml')
            
            title = self.extract_title(soup)
            content = self.extract_content(soup)
            if not content:
                return False
            
            self.fix_paths_in_content(content)
            css_files = self.collect_css(soup)
            js_files = self.collect_js(soup)
            clean_html = self.build_clean_html(title, content, css_files, js_files)
            
            html_file.write_text(clean_html, encoding='utf-8')
            self.converted += 1
            return True
        except Exception as e:
            print(f"   ✗ Error {html_file.name}: {e}")
            return False
    
    def restructure_pages(self, cwd: Path) -> None:
        html_files = [f for f in cwd.glob('*.html') if f.name not in ['index.html', '404.html']]
        if not html_files:
            return
        
        restructured = 0
        for html_file in html_files:
            try:
                page_name = html_file.stem
                page_dir = cwd / page_name
                page_dir.mkdir(exist_ok=True)
                target = page_dir / 'index.html'
                shutil.move(str(html_file), str(target))
                restructured += 1
            except Exception as e:
                print(f"   ✗ Error: {html_file.name}: {e}")
        
        if restructured:
            print(f"✅ Restructured {restructured} pages\n")
    
    def create_404_page(self, cwd: Path) -> None:
        page_404 = cwd / '404.html'
        if page_404.exists():
            return
        
        homepage = f'{self.base_path}/' if self.base_path != '/' else '/'
        content = f'<main><h1>404 - Page Not Found</h1><p><a href="{homepage}">Go to Homepage</a></p></main>'
        
        html = self.CLEAN_TEMPLATE.format(
            title="404 - Page Not Found",
            critical_css='',
            meta_tags='',
            content=content,
            scripts=''
        )
        page_404.write_text(html, encoding='utf-8')
        print("✅ Created 404.html\n")
    
    def run(self) -> int:
        cwd = Path.cwd()
        
        print(f"\n🔥 WORDPRESS DESTROYER")
        print(f"Base path: {self.base_path}")
        if self.original_domain:
            print(f"Original domain: {self.original_domain}")
        print("=" * 60)
        
        html_files = [
            f for f in cwd.rglob('*.html')
            if '.git' not in f.parts and '.github' not in f.parts
        ]
        
        if not html_files:
            print("⚠️ No HTML files found")
            return 1
        
        print(f"Found {len(html_files)} HTML files\n")
        
        for html_file in html_files:
            if self.convert_file(html_file):
                rel_path = html_file.relative_to(cwd)
                print(f"   ✓ {rel_path}")
        
        print(f"\n✅ Converted {self.converted} files")
        print(f"🔗 Converted {self.converted_absolute_urls} absolute URLs")
        print(f"🗑️  Removed {self.cleaned_scripts} WP scripts")
        print(f"🗑️  Removed {self.cleaned_styles} WP styles\n")
        
        self.restructure_pages(cwd)
        self.create_404_page(cwd)
        
        print(f"📦 CSS: {len(self.css_files)}, JS: {len(self.js_files)}")
        print("\n✅ WORDPRESS DESTROYED\n")
        
        return 0


if __name__ == '__main__':
    try:
        base_path = os.getenv('BASE_PATH', '/')
        original_domain = os.getenv('ORIGINAL_DOMAIN', '')
        destroyer = WordPressDestroyer(base_path=base_path, original_domain=original_domain)
        sys.exit(destroyer.run())
    except KeyboardInterrupt:
        print("\n⚠️ Interrupted")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Fatal: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
