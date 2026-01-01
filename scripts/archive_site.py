#!/usr/bin/env python3
"""Complete site archiver with CSS, JS, images and all assets.

Features:
- Downloads complete HTML with all external resources
- Saves CSS files (inline and external)
- Saves JavaScript files
- Downloads images, fonts, and other media
- Fixes relative paths in HTML/CSS
- Supports recursive crawling within same domain
"""

import os
import re
import sys
import json
import argparse
import requests
from pathlib import Path
from urllib.parse import urljoin, urlparse, urlunparse
from bs4 import BeautifulSoup
from typing import Set, Dict, Optional
import hashlib
import time


class SiteArchiver:
    def __init__(self, base_url: str, output_dir: str, max_depth: int = 2):
        self.base_url = base_url.rstrip('/')
        self.output_dir = Path(output_dir)
        self.max_depth = max_depth
        self.visited_urls: Set[str] = set()
        self.downloaded_resources: Dict[str, str] = {}  # URL -> local path
        self.domain = urlparse(base_url).netloc
        
        # Create output directory
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
        # Session for requests
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        })
    
    def get_local_path(self, url: str, resource_type: str = 'html') -> Path:
        """Generate local path for URL."""
        parsed = urlparse(url)
        
        # Clean path
        path = parsed.path.strip('/')
        if not path:
            path = 'index.html'
        elif not os.path.splitext(path)[1]:  # No extension
            path = f"{path}/index.html"
        
        # Handle query strings
        if parsed.query:
            # Hash query to avoid long filenames
            query_hash = hashlib.md5(parsed.query.encode()).hexdigest()[:8]
            base, ext = os.path.splitext(path)
            path = f"{base}_{query_hash}{ext or '.html'}"
        
        return self.output_dir / path
    
    def download_resource(self, url: str, referer: Optional[str] = None) -> Optional[str]:
        """Download resource and return local path."""
        if url in self.downloaded_resources:
            return self.downloaded_resources[url]
        
        try:
            headers = {}
            if referer:
                headers['Referer'] = referer
            
            print(f"  ⬇️  Downloading: {url}")
            response = self.session.get(url, headers=headers, timeout=30, allow_redirects=True)
            response.raise_for_status()
            
            # Determine local path
            local_path = self.get_local_path(url, self._get_resource_type(url))
            local_path.parent.mkdir(parents=True, exist_ok=True)
            
            # Write content
            if response.headers.get('content-type', '').startswith('text/'):
                content = response.text
                # Fix paths in CSS
                if url.endswith('.css'):
                    content = self._fix_css_paths(content, url)
                local_path.write_text(content, encoding='utf-8')
            else:
                local_path.write_bytes(response.content)
            
            # Store mapping
            rel_path = local_path.relative_to(self.output_dir)
            self.downloaded_resources[url] = str(rel_path)
            
            return str(rel_path)
            
        except Exception as e:
            print(f"  ❌ Failed to download {url}: {e}")
            return None
    
    def _get_resource_type(self, url: str) -> str:
        """Detect resource type from URL."""
        ext = os.path.splitext(urlparse(url).path)[1].lower()
        if ext in ['.css']:
            return 'css'
        elif ext in ['.js']:
            return 'js'
        elif ext in ['.jpg', '.jpeg', '.png', '.gif', '.svg', '.webp', '.ico']:
            return 'image'
        elif ext in ['.woff', '.woff2', '.ttf', '.otf', '.eot']:
            return 'font'
        return 'other'
    
    def _fix_css_paths(self, css_content: str, css_url: str) -> str:
        """Fix URLs in CSS (url() references)."""
        def replace_url(match):
            original_url = match.group(1).strip('\'"')
            if original_url.startswith('data:'):
                return match.group(0)
            
            absolute_url = urljoin(css_url, original_url)
            local_path = self.download_resource(absolute_url, css_url)
            
            if local_path:
                # Calculate relative path from CSS location
                css_local = self.get_local_path(css_url)
                try:
                    rel_path = os.path.relpath(
                        self.output_dir / local_path,
                        css_local.parent
                    )
                    return f'url("{rel_path}")'
                except ValueError:
                    return f'url("{local_path}")'
            
            return match.group(0)
        
        return re.sub(r'url\(["\']?([^"\')]+)["\']?\)', replace_url, css_content)
    
    def process_html(self, url: str, depth: int = 0) -> Optional[str]:
        """Process HTML page and download all resources."""
        if url in self.visited_urls or depth > self.max_depth:
            return None
        
        # Check if same domain
        if urlparse(url).netloc != self.domain:
            return None
        
        self.visited_urls.add(url)
        print(f"\n🌐 Processing [{depth}]: {url}")
        
        try:
            response = self.session.get(url, timeout=30)
            response.raise_for_status()
            
            soup = BeautifulSoup(response.text, 'html.parser')
            
            # Download CSS
            for link in soup.find_all('link', rel='stylesheet'):
                if link.get('href'):
                    css_url = urljoin(url, link['href'])
                    local_path = self.download_resource(css_url, url)
                    if local_path:
                        # Update href to local path
                        current_page_path = self.get_local_path(url)
                        try:
                            rel_path = os.path.relpath(
                                self.output_dir / local_path,
                                current_page_path.parent
                            )
                            link['href'] = rel_path
                        except ValueError:
                            link['href'] = local_path
            
            # Download JavaScript
            for script in soup.find_all('script', src=True):
                js_url = urljoin(url, script['src'])
                local_path = self.download_resource(js_url, url)
                if local_path:
                    current_page_path = self.get_local_path(url)
                    try:
                        rel_path = os.path.relpath(
                            self.output_dir / local_path,
                            current_page_path.parent
                        )
                        script['src'] = rel_path
                    except ValueError:
                        script['src'] = local_path
            
            # Download images
            for img in soup.find_all('img', src=True):
                img_url = urljoin(url, img['src'])
                local_path = self.download_resource(img_url, url)
                if local_path:
                    current_page_path = self.get_local_path(url)
                    try:
                        rel_path = os.path.relpath(
                            self.output_dir / local_path,
                            current_page_path.parent
                        )
                        img['src'] = rel_path
                    except ValueError:
                        img['src'] = local_path
            
            # Process inline styles
            for style_tag in soup.find_all('style'):
                if style_tag.string:
                    style_tag.string = self._fix_css_paths(style_tag.string, url)
            
            # Save HTML
            local_path = self.get_local_path(url)
            local_path.parent.mkdir(parents=True, exist_ok=True)
            local_path.write_text(str(soup), encoding='utf-8')
            
            print(f"  ✅ Saved: {local_path.relative_to(self.output_dir)}")
            
            # Process links (recursive)
            if depth < self.max_depth:
                for link in soup.find_all('a', href=True):
                    next_url = urljoin(url, link['href'])
                    # Remove fragment
                    next_url = urlunparse(urlparse(next_url)._replace(fragment=''))
                    
                    if urlparse(next_url).netloc == self.domain:
                        time.sleep(0.5)  # Be polite
                        self.process_html(next_url, depth + 1)
            
            return str(local_path.relative_to(self.output_dir))
            
        except Exception as e:
            print(f"  ❌ Failed to process {url}: {e}")
            return None
    
    def create_metadata(self):
        """Create metadata file."""
        metadata = {
            'base_url': self.base_url,
            'archived_at': time.strftime('%Y-%m-%d %H:%M:%S UTC', time.gmtime()),
            'total_pages': len([u for u in self.visited_urls]),
            'total_resources': len(self.downloaded_resources),
            'pages': list(self.visited_urls),
        }
        
        metadata_path = self.output_dir / 'archive_metadata.json'
        metadata_path.write_text(json.dumps(metadata, indent=2), encoding='utf-8')
        print(f"\n📋 Metadata saved: {metadata_path}")
    
    def archive(self):
        """Start archiving process."""
        print(f"🚀 Starting archive of {self.base_url}")
        print(f"📁 Output directory: {self.output_dir}")
        print(f"🔍 Max depth: {self.max_depth}\n")
        
        start_time = time.time()
        
        # Start with base URL
        self.process_html(self.base_url, depth=0)
        
        # Create metadata
        self.create_metadata()
        
        elapsed = time.time() - start_time
        print(f"\n✨ Archive complete!")
        print(f"⏱️  Time: {elapsed:.2f}s")
        print(f"📄 Pages: {len(self.visited_urls)}")
        print(f"📦 Resources: {len(self.downloaded_resources)}")


def main():
    parser = argparse.ArgumentParser(
        description='Archive website with all CSS, JS, and assets'
    )
    parser.add_argument('url', help='Website URL to archive')
    parser.add_argument(
        '-o', '--output',
        default='archived_sites',
        help='Output directory (default: archived_sites)'
    )
    parser.add_argument(
        '-d', '--depth',
        type=int,
        default=2,
        help='Maximum crawl depth (default: 2)'
    )
    
    args = parser.parse_args()
    
    # Extract domain for folder name
    domain = urlparse(args.url).netloc
    output_dir = os.path.join(args.output, domain)
    
    archiver = SiteArchiver(args.url, output_dir, max_depth=args.depth)
    archiver.archive()


if __name__ == '__main__':
    main()
