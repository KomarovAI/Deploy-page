#!/usr/bin/env python3
"""
Validate all links in static HTML site - detects 404s before deployment
Filters out WordPress CMS artifacts that don't belong in static exports
"""
import os
import sys
import json
from pathlib import Path
from html.parser import HTMLParser
from urllib.parse import urljoin, urlparse

class LinkExtractor(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []
    
    def handle_starttag(self, tag, attrs):
        if tag in ['a', 'link', 'script', 'img', 'source']:
            for attr, value in attrs:
                if attr in ['href', 'src'] and value:
                    self.links.append(value)

def is_wp_artifact(link_path):
    """Check if link is WordPress CMS artifact that shouldn't exist in static export"""
    wp_patterns = (
        'wp-json/',          # REST API endpoints
        'wp-content/plugins/',  # Plugin files
        'wp-content/cache/',    # Cache files
        'wp-includes/',         # WordPress core
    )
    return any(pattern in link_path for pattern in wp_patterns) or link_path.endswith('.php')

def validate_site(site_path):
    """Scan all HTML files and check link targets exist"""
    site_path = Path(site_path)
    broken = []
    checked = set()
    
    for html_file in sorted(site_path.rglob("*.html")):
        try:
            with open(html_file, 'r', encoding='utf-8', errors='ignore') as f:
                parser = LinkExtractor()
                parser.feed(f.read())
                
                for link in parser.links:
                    # Skip external/anchors
                    if link.startswith(('http://', 'https://', '#', 'mailto:', 'tel:', 'javascript:')):
                        continue
                    
                    # Normalize path
                    link_path = urlparse(link).path.split('?')[0]
                    
                    # Skip WordPress artifacts
                    if is_wp_artifact(link_path):
                        continue
                    
                    # Resolve relative to HTML file location
                    if link_path.startswith('/'):
                        target = site_path / link_path.lstrip('/')
                    else:
                        target = (html_file.parent / link_path).resolve()
                    
                    # Check if exists (cache checks)
                    target_key = str(target)
                    if target_key in checked:
                        continue
                    checked.add(target_key)
                    
                    if not target.exists():
                        broken.append({
                            'source': str(html_file.relative_to(site_path)),
                            'link': link,
                            'target': str(target.relative_to(site_path)) if target.is_relative_to(site_path) else str(target)
                        })
        except Exception as e:
            print(f"⚠️  Error reading {html_file}: {e}", file=sys.stderr)
    
    return broken

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 validate-links.py <site_path>")
        sys.exit(1)
    
    site_path = sys.argv[1]
    
    if not Path(site_path).exists():
        print(f"❌ Path not found: {site_path}")
        sys.exit(1)
    
    print(f"🔍 Scanning {site_path} for broken links...")
    broken = validate_site(site_path)
    
    if broken:
        print(f"\n❌ Found {len(broken)} broken links:\n")
        for item in broken[:15]:
            print(f"  📄 {item['source']}")
            print(f"     → {item['link']}")
            print(f"     ✗ Target: {item['target']}\n")
        
        if len(broken) > 15:
            print(f"  ... and {len(broken) - 15} more\n")
        
        # Save report
        with open('broken-links.json', 'w') as f:
            json.dump(broken, f, indent=2)
        print(f"📋 Full report saved to: broken-links.json")
        sys.exit(1)
    else:
        print("✅ All links validated successfully!")
        sys.exit(0)

if __name__ == '__main__':
    main()
