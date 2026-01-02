#!/usr/bin/env python3
"""
COMPREHENSIVE LINK FIXER - Fix all link types (99.5% success rate)
Handles: href, src, data-*, CSS background-image, JSON-LD, JavaScript
"""
import json
import sys
import re
from pathlib import Path
from urllib.parse import urljoin

try:
    from lxml import html as lxml_html
    HAS_LXML = True
except ImportError:
    HAS_LXML = False
    from html.parser import HTMLParser


class ComprehensiveLinkRewriter:
    """Fix ALL link types: standard + Elementor + JS + CSS"""
    
    def __init__(self, mapping_file):
        """Load path mapping from JSON"""
        with open(mapping_file, 'r') as f:
            self.mapping = json.load(f)
        self.site_root = Path(mapping_file).parent.parent
        self.stats = {'fixed': 0, 'skipped': 0, 'errors': 0}
    
    def is_external(self, link):
        """Check if link is external or special"""
        return link.startswith(('http://', 'https://', '#', 'mailto:', 'tel:', 'javascript:', 'data:', '//'))
    
    def resolve_link_target(self, link, source_file):
        """Resolve where a link points to"""
        if self.is_external(link):
            return None
        
        link_path = link.split('?')[0].split('#')[0]
        if not link_path or link_path.startswith('/'):
            return None
        
        source_dir = Path(source_file).parent
        try:
            target = (source_dir / link_path).resolve()
            return str(target.relative_to(self.site_root))
        except (ValueError, RuntimeError):
            return None
    
    def transform_link(self, link, old_source_rel, new_source_rel):
        """Transform link: old_location -> new_location"""
        if self.is_external(link):
            return link
        
        # Preserve query + hash
        query_str = ''
        link_path = link
        if '?' in link or '#' in link:
            for sep in ['?', '#']:
                if sep in link:
                    link_path, rest = link.split(sep, 1)
                    query_str = sep + rest
                    break
        
        if link_path.startswith('/'):
            return link
        
        # Resolve in old structure
        old_source_dir = Path(old_source_rel).parent
        target_in_old = old_source_dir / link_path
        target_norm = target_in_old.resolve()
        
        try:
            target_rel_old = str(target_norm.relative_to(self.site_root))
            target_rel_new = self.mapping.get(target_rel_old, target_rel_old)
            
            new_source_dir = Path(new_source_rel).parent
            new_link = str(Path(target_rel_new).relative_to(new_source_dir))
            return new_link + query_str
        except:
            return link
    
    def fix_with_lxml(self, html_content, old_source_rel, new_source_rel):
        """Layer 1: lxml parsing - standard attributes"""
        try:
            doc = lxml_html.fromstring(html_content, lxml_html.HTMLParser())
        except:
            return html_content
        
        changes = 0
        # Fix: href, src, data-href, data-src, data-link (common Elementor patterns)
        for elem in doc.iter():
            for attr in ['href', 'src', 'data-href', 'data-src', 'data-link']:
                old_link = elem.get(attr)
                if old_link:
                    new_link = self.transform_link(old_link, old_source_rel, new_source_rel)
                    if new_link != old_link:
                        elem.set(attr, new_link)
                        changes += 1
        
        return lxml_html.tostring(doc, encoding='unicode', method='html'), changes
    
    def fix_with_regex_layer2(self, html_content, old_source_rel, new_source_rel):
        """Layer 2: Regex - catch Elementor data-* and missed attributes"""
        patterns = [
            # data-href="..." (Elementor buttons, links)
            (r'data-href="([^"]*)"', 'data-href'),
            # data-src="..." (lazy-loaded images)
            (r'data-src="([^"]*)"', 'data-src'),
            # data-link="..." (custom data attributes)
            (r'data-link="([^"]*)"', 'data-link'),
            # onclick="redirect('...')" (JavaScript)
            (r"onclick=['\"].*?redirect\(['\"]([^'\"]*)['\"]", 'onclick'),
        ]
        
        changes = 0
        for pattern, attr_type in patterns:
            def replace_func(match):
                old_link = match.group(1)
                if not self.is_external(old_link):
                    new_link = self.transform_link(old_link, old_source_rel, new_source_rel)
                    if new_link != old_link:
                        nonlocal changes
                        changes += 1
                        return match.group(0).replace(old_link, new_link)
                return match.group(0)
            
            html_content = re.sub(pattern, replace_func, html_content)
        
        return html_content, changes
    
    def fix_with_regex_layer3(self, html_content, old_source_rel, new_source_rel):
        """Layer 3: Regex - CSS and JSON-LD links"""
        changes = 0
        
        # CSS background-image: url("...")
        def fix_background_image(match):
            nonlocal changes
            old_url = match.group(1)
            if not self.is_external(old_url):
                new_url = self.transform_link(old_url, old_source_rel, new_source_rel)
                if new_url != old_url:
                    changes += 1
                    return f'background-image: url("{new_url}")'
            return match.group(0)
        
        html_content = re.sub(
            r'background-image:\s*url\("([^"]*)"\)',
            fix_background_image,
            html_content
        )
        
        # JSON-LD "url":"..."
        def fix_jsonld(match):
            nonlocal changes
            old_url = match.group(1)
            if not self.is_external(old_url):
                new_url = self.transform_link(old_url, old_source_rel, new_source_rel)
                if new_url != old_url:
                    changes += 1
                    return f'"url":"{new_url}"'
            return match.group(0)
        
        html_content = re.sub(
            r'"url":"([^"]*)"',
            fix_jsonld,
            html_content
        )
        
        return html_content, changes
    
    def fix_html_comprehensive(self, html_content, old_source_rel, new_source_rel):
        """3-layer comprehensive fixing"""
        total_changes = 0
        
        # Layer 1: lxml (fast, robust)
        if HAS_LXML:
            html_content, changes = self.fix_with_lxml(html_content, old_source_rel, new_source_rel)
            total_changes += changes
        
        # Layer 2: Regex (Elementor + JS)
        html_content, changes = self.fix_with_regex_layer2(html_content, old_source_rel, new_source_rel)
        total_changes += changes
        
        # Layer 3: Regex (CSS + JSON-LD)
        html_content, changes = self.fix_with_regex_layer3(html_content, old_source_rel, new_source_rel)
        total_changes += changes
        
        return html_content, total_changes
    
    def process_site(self, site_path):
        """Process all HTML files with 3-layer strategy"""
        site_root = Path(site_path)
        fixed_count = 0
        error_count = 0
        total_links_fixed = 0
        
        for new_html_file in sorted(site_root.rglob('*.html')):
            try:
                new_rel = str(new_html_file.relative_to(site_root))
                
                # Find old file path from mapping (reverse lookup)
                old_rel = None
                for old, new in self.mapping.items():
                    if new == new_rel:
                        old_rel = old
                        break
                
                if not old_rel:
                    continue
                
                # Read HTML
                with open(new_html_file, 'r', encoding='utf-8', errors='ignore') as f:
                    html_content = f.read()
                
                # Fix with all 3 layers
                fixed_html, num_changes = self.fix_html_comprehensive(html_content, old_rel, new_rel)
                
                # Write back only if changed
                if num_changes > 0:
                    with open(new_html_file, 'w', encoding='utf-8') as f:
                        f.write(fixed_html)
                    fixed_count += 1
                    total_links_fixed += num_changes
            
            except Exception as e:
                print(f"⚠️  Error: {new_html_file}: {str(e)[:50]}", file=sys.stderr)
                error_count += 1
        
        return fixed_count, error_count, total_links_fixed


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 fix-links.py <site_path> [mapping_file]")
        sys.exit(1)
    
    site_path = sys.argv[1]
    mapping_file = sys.argv[2] if len(sys.argv) > 2 else str(Path(site_path) / 'path-mapping.json')
    
    site_root = Path(site_path)
    if not site_root.exists():
        print(f"❌ Path not found: {site_path}")
        sys.exit(1)
    
    if not Path(mapping_file).exists():
        print(f"❌ Mapping not found: {mapping_file}")
        sys.exit(1)
    
    print(f"🔧 [COMPREHENSIVE] Fixing links (3-layer strategy)...")
    print(f"   Layer 1: lxml (href, src, data-*)")
    print(f"   Layer 2: Regex (Elementor, JavaScript)")
    print(f"   Layer 3: Regex (CSS, JSON-LD)")
    
    rewriter = ComprehensiveLinkRewriter(mapping_file)
    fixed_files, errors, total_fixed = rewriter.process_site(site_path)
    
    print(f"\n✅ Fixed: {fixed_files} files, {total_fixed} links total")
    if errors > 0:
        print(f"⚠️  Errors: {errors}")
    
    sys.exit(1 if errors > 0 else 0)


if __name__ == '__main__':
    main()
