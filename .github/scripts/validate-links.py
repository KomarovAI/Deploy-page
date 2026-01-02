#!/usr/bin/env python3
"""
COMPREHENSIVE LINK VALIDATOR - Detect all broken links before deployment
Supports: standard links + Elementor data-* + CSS + JSON-LD + JavaScript
"""
import os
import sys
import json
import re
from pathlib import Path
from html.parser import HTMLParser
from urllib.parse import urljoin, urlparse
from collections import defaultdict


class ComprehensiveLinkExtractor(HTMLParser):
    """Extract ALL link types: standard + data-* + CSS + JSON-LD"""
    
    def __init__(self):
        super().__init__()
        self.links = []
        self.in_script = False
        self.in_style = False
        self.current_script = ""
        self.current_style = ""
    
    def handle_starttag(self, tag, attrs):
        if tag == 'script':
            self.in_script = True
            return
        if tag == 'style':
            self.in_style = True
            return
        
        # Standard tags: href, src
        if tag in ['a', 'link', 'script', 'img', 'source', 'form', 'area']:
            for attr, value in attrs:
                if attr in ['href', 'src', 'action'] and value:
                    self.links.append(value)
        
        # Elementor + WordPress data attributes
        if tag in ['a', 'div', 'img', 'button', 'section']:
            for attr, value in attrs:
                if attr in ['data-href', 'data-src', 'data-link', 'data-url'] and value:
                    self.links.append(value)
        
        # Background images in inline style
        if 'style' in dict(attrs):
            style = dict(attrs)['style']
            # Extract background-image URLs
            bg_urls = re.findall(r'url\(["\']?([^")\']*)["\']*\)', style)
            self.links.extend(bg_urls)
    
    def handle_endtag(self, tag):
        if tag == 'script':
            self.in_script = False
            # Extract onclick handlers and javascript URLs
            js_urls = re.findall(r"(?:href|src|url)=['\"]((?!javascript:)[^'\"]*)['\"]|onclick=.*?['\"]([^'\"]*)['\"]|window\.location[=\s]+['\"]([^'\"]*)['\"]|\.href\s*=\s*['\"]([^'\"]*)[\'\"]|redirect\(['\"]([^'\"]*)[\'\"]\)", self.current_script)
            self.links.extend([url for group in js_urls for url in group if url])
            self.current_script = ""
        
        if tag == 'style':
            self.in_style = False
            # Extract background URLs from CSS
            css_urls = re.findall(r'url\(["\']?([^")\']*)["\']*\)', self.current_style)
            self.links.extend(css_urls)
            self.current_style = ""
    
    def handle_data(self, data):
        if self.in_script:
            self.current_script += data
        if self.in_style:
            self.current_style += data
        
        # Extract JSON-LD URLs from inline script
        if '{' in data and '"url"' in data:
            json_urls = re.findall(r'"url"\s*:\s*"([^"]*)"', data)
            self.links.extend(json_urls)


class LinkValidator:
    """Validate all links and generate reports"""
    
    def __init__(self, site_path):
        self.site_path = Path(site_path)
        self.broken = []
        self.checked = set()
        self.skipped = defaultdict(int)
        self.file_stats = {}
    
    def is_external(self, link):
        """Check if link is external or should be skipped"""
        # External URLs
        if link.startswith(('http://', 'https://', 'ftp://', 'ftps://', '//', 'www.')):
            return True
        
        # Special URLs
        if link.startswith(('#', 'mailto:', 'tel:', 'sms:', 'javascript:', 'about:', 'data:')):
            return True
        
        # WordPress/plugin URLs
        if 'wp-json' in link or 'wp-admin' in link or 'wp-content' in link or 'wp-includes' in link:
            if 'oembed' in link or 'api' in link:
                return True
        
        # PHP files (dynamic content)
        if link.endswith('.php'):
            return True
        
        return False
    
    def normalize_link(self, link):
        """Normalize link path"""
        # Remove query strings and anchors
        link = link.split('?')[0].split('#')[0]
        
        # Remove leading/trailing whitespace
        link = link.strip()
        
        return link
    
    def validate_link(self, link, source_file):
        """Check if link target exists"""
        if not link:
            self.skipped['empty'] += 1
            return True
        
        if self.is_external(link):
            self.skipped['external'] += 1
            return True
        
        link = self.normalize_link(link)
        
        if not link:
            self.skipped['normalized_empty'] += 1
            return True
        
        # Resolve link target
        try:
            if link.startswith('/'):
                target = self.site_path / link.lstrip('/')
            else:
                target = (source_file.parent / link).resolve()
            
            # Cache check
            target_key = str(target)
            if target_key in self.checked:
                return target_key in [str(Path(b['target'])) for b in self.broken]
            
            self.checked.add(target_key)
            
            # Check existence
            if not target.exists():
                return False
            
            return True
        
        except Exception as e:
            self.skipped['error'] += 1
            return True
    
    def validate_site(self):
        """Scan all HTML files for broken links"""
        for html_file in sorted(self.site_path.rglob('*.html')):
            file_key = str(html_file.relative_to(self.site_path))
            self.file_stats[file_key] = {'checked': 0, 'broken': 0}
            
            try:
                with open(html_file, 'r', encoding='utf-8', errors='ignore') as f:
                    parser = ComprehensiveLinkExtractor()
                    parser.feed(f.read())
                
                for link in parser.links:
                    if link and link not in ['', ' ']:
                        self.file_stats[file_key]['checked'] += 1
                        
                        if not self.validate_link(link, html_file):
                            self.broken.append({
                                'source': file_key,
                                'link': link,
                                'target': link  # Store original for debugging
                            })
                            self.file_stats[file_key]['broken'] += 1
            
            except Exception as e:
                print(f"⚠️  Error reading {file_key}: {str(e)[:50]}", file=sys.stderr)
    
    def generate_report(self):
        """Generate detailed report"""
        report = {
            'summary': {
                'total_broken': len(self.broken),
                'files_checked': len(self.file_stats),
                'total_links_checked': sum(f['checked'] for f in self.file_stats.values()),
                'skipped_external': self.skipped['external'],
                'skipped_special': sum(v for k, v in self.skipped.items() if k != 'external')
            },
            'broken_links': self.broken[:50],  # First 50 for detailed view
            'files_with_errors': [
                {'file': k, 'broken': v['broken']} 
                for k, v in self.file_stats.items() 
                if v['broken'] > 0
            ][:20]
        }
        return report


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 validate-links.py <site_path>")
        sys.exit(1)
    
    site_path = sys.argv[1]
    
    if not Path(site_path).exists():
        print(f"❌ Path not found: {site_path}")
        sys.exit(1)
    
    print(f"🔍 COMPREHENSIVE validation of {site_path}...")
    
    validator = LinkValidator(site_path)
    validator.validate_site()
    
    report = validator.generate_report()
    
    # Display results
    summary = report['summary']
    print(f"\n📊 Validation Summary:")
    print(f"   Files scanned: {summary['files_checked']}")
    print(f"   Links checked: {summary['total_links_checked']}")
    print(f"   Broken links: {summary['total_broken']}")
    print(f"   Skipped (external): {summary['skipped_external']}")
    
    if validator.broken:
        print(f"\n❌ BROKEN LINKS FOUND:")
        for item in report['broken_links'][:20]:
            print(f"   📄 {item['source']}")
            print(f"      → {item['link']}")
        
        if len(validator.broken) > 20:
            print(f"\n   ... and {len(validator.broken) - 20} more")
        
        # Save detailed report
        with open('validation-report.json', 'w') as f:
            json.dump(report, f, indent=2)
        print(f"\n📋 Full report: validation-report.json")
        
        sys.exit(1)
    else:
        print(f"\n✅ ALL LINKS VALID - Ready for deployment!")
        sys.exit(0)


if __name__ == '__main__':
    main()
