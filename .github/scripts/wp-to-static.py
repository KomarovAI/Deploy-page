#!/usr/bin/env python3
"""WordPress to Static Site Converter with auto-detection."""

import sys
import os
import shutil
from pathlib import Path
from typing import Dict, List, Set, Optional
from collections import Counter
import re
from urllib.parse import urlparse

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
        self.original_domain = original_domain.rstrip('/') if original_domain else None
        self.converted = 0
        self.cleaned_scripts = 0
        self.cleaned_styles = 0
        self.converted_absolute_urls = 0
        self.css_files: Set[str] = set()
        self.js_files: Set[str] = set()
    
    def auto_detect_domain(self, html_files: List[Path]) -> Optional[str]:
        """Auto-detect original domain from HTML files."""
        domains = []
        
        sample_files = html_files[:min(10, len(html_files))]
        
        for html_file in sample_files:
            try:
                content = html_file.read_text(encoding='utf-8', errors='ignore')
                soup = BeautifulSoup(content, 'lxml')
                
                canonical = soup.find('link', rel='canonical', href=True)
                if canonical:
                    parsed = urlparse(canonical['href'])
                    if parsed.scheme and parsed.netloc:
                        domains.append(f"{parsed.scheme}://{parsed.netloc}")
                
                og_url = soup.find('meta', property='og:url', content=True)
                if og_url:
                    parsed = urlparse(og_url['content'])
                    if parsed.scheme and parsed.netloc:
                        domains.append(f"{parsed.scheme}://{parsed.netloc}")
                
                for tag in soup.find_all(['a', 'img', 'link', 'script'], href=True):
                    url = tag.get('href') or tag.get('src')
                    if url and url.startswith(('http://', 'https://')):
                        parsed = urlparse(url)
                        if parsed.netloc:
                            domains.append(f"{parsed.scheme}://{parsed.netloc}")
                
                for tag in soup.find_all(['img', 'script'], src=True):
                    url = tag['src']
                    if url.startswith(('http://', 'https://')):
                        parsed = urlparse(url)
                        if parsed.netloc:
                            domains.append(f"{parsed.scheme}://{parsed.netloc}")
                
            except Exception:
                continue
        
        if not domains:
            return None
        
        domain_counts = Counter(domains)
        most_common = domain_counts.most_common(1)[0][0]
        
        cdn_patterns = ['googleapis', 'gstatic', 'cloudflare', 'jsdelivr', 'unpkg', 'cdnjs']
        filtered = [d for d in domain_counts.keys() 
                   if not any(pattern in d.lower() for pattern in cdn_patterns)]
        
        if filtered:
            return Counter({d: domain_counts[d] for d in filtered}).most_common(1)[0][0]
        
        return most_common
    
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
        """FIXED: правильное извлечение без вложенности."""
        selectors = ['main', '.entry-content', 'article', '#content', '.site-content']
        
        for selector in selectors:
            content = soup.select_one(selector)
            if content:
                clean_content = content.extract()
                
                for nested_tag in clean_content.find_all(['html', 'body', 'head']):
                    nested_tag.unwrap()
                
                for junk in clean_content.select('.wp-block-code, .sharedaddy, .jp-relatedposts, script, style, noscript'):
                    junk.decompose()
                
                return clean_content
        
        body = soup.find('body')
        if body:
            body_copy = body.extract()
            for nested in body_copy.find_all(['html', 'body', 'head']):
                nested.unwrap()
            for junk in body_copy.select('script, style, noscript'):
                junk.decompose()
            return body_copy
        
        return None
    
    def fix_lazy_load_images(self, content: Tag) -> None:
        """FIX: Конвертация lazy-load → обычные изображения."""
        for img in content.find_all('img'):
            if img.get('data-src'):
                img['src'] = img['data-src']
                del img['data-src']
            
            if img.get('data-srcset'):
                img['srcset'] = img['data-srcset']
                del img['data-srcset']
            
            for attr in ['data-src-webp', 'data-srcset-webp', 'data-eio', 'data-eio-rwidth', 'data-eio-rheight']:
                if img.get(attr):
                    del img[attr]
            
            if img.get('class'):
                img['class'] = [c for c in img['class'] if 'lazy' not in c.lower()]
                if not img['class']:
                    del img['class']
    
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
        
        if url.startswith(('#', 'mailto:', 'tel:', 'javascript:', 'data:')):
            return url
        
        original_url = url
        
        if self.original_domain and url.startswith(('http://', 'https://', '//')):
            if url.startswith('//'):
                url = 'https:' + url
            
            domain_variants = [
                self.original_domain,
                self.original_domain.replace('https://', 'http://'),
                self.original_domain.replace('http://', 'https://'),
                self.original_domain.replace('https://', '//'),
                self.original_domain.replace('http://', '//')
            ]
            
            for domain in domain_variants:
                if url.startswith(domain):
                    url = url[len(domain):]
                    if not url.startswith('/'):
                        url = '/' + url
                    self.converted_absolute_urls += 1
                    break
            else:
                return original_url
        
        if url.startswith(('http://', 'https://', '//')):
            return url
        
        anchor = ''
        if '#' in url:
            url, anchor = url.split('#', 1)
            anchor = '#' + anchor
        
        query = ''
        if '?' in url:
            url, query = url.split('?', 1)
            query = '?' + query
        
        clean_url = url.lstrip('./')
        
        if clean_url and not clean_url.endswith(('.html', '/')):
            if '.' not in clean_url.split('/')[-1]:
                clean_url += '.html'
        
        result = f"{self.base_path}/{clean_url}" if self.base_path else f"/{clean_url}"
        return result + query + anchor
    
    def fix_paths_in_content(self, content: Tag) -> None:
        for img in content.find_all('img', src=True):
            img['src'] = self.fix_url(img['src'])
        
        for tag in content.find_all(attrs={'data-bg': True}):
            tag['data-bg'] = self.fix_url(tag['data-bg'])
        for tag in content.find_all(attrs={'data-background': True}):
            tag['data-background'] = self.fix_url(tag['data-background'])
        
        for a in content.find_all('a', href=True):
            a['href'] = self.fix_url(a['href'])
        
        for tag in content.find_all(style=True):
            style = tag['style']
            def replace_url(match):
                url = match.group(1).strip('"\'')
                fixed = self.fix_url(url)
                return f'url("{fixed}")'
            tag['style'] = re.sub(r'url\(([^)]+)\)', replace_url, style)
    
    def build_clean_html(self, title: str, content: Tag, css_files: List[str], js_files: List[str]) -> str:
        css_links = []
        for css in css_files:
            href = f"{self.base_path}/{css}" if self.base_path else f"/{css}"
            css_links.append(f'    <link rel="stylesheet" href="{href}">')
        critical_css = '\n'.join(css_links) if css_links else ''
        
        js_scripts = []
        for js in js_files:
            src = f"{self.base_path}/{js}" if self.base_path else f"/{js}"
            js_scripts.append(f'    <script src="{src}" defer></script>')
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
            
            self.fix_lazy_load_images(content)
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
        
        homepage = f'{self.base_path}/' if self.base_path else '/'
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
        
        html_files = [
            f for f in cwd.rglob('*.html')
            if '.git' not in f.parts and '.github' not in f.parts
        ]
        
        if not html_files:
            print("⚠️ No HTML files found")
            return 1
        
        if not self.original_domain:
            print("🔍 Auto-detecting original domain...")
            detected = self.auto_detect_domain(html_files)
            if detected:
                self.original_domain = detected
                print(f"✅ Detected: {self.original_domain}")
            else:
                print("⚠️ Could not detect original domain - skipping absolute URL conversion")
        
        print(f"\n🔥 WORDPRESS DESTROYER")
        print(f"Base path: {self.base_path if self.base_path else '/'}")
        if self.original_domain:
            print(f"Original domain: {self.original_domain}")
        print("=" * 60)
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
