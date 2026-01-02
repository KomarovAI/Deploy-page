#!/usr/bin/env python3
"""
Fix broken links using lxml.html
Rewrite all href/src attributes when files are restructured
Solution: page.html -> page/index.html requires relative path adjustments
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


class LinkRewriter:
    """Rewrite links in HTML files when structure changes"""
    
    def __init__(self, mapping_file):
        """Load path mapping from JSON"""
        with open(mapping_file, 'r') as f:
            self.mapping = json.load(f)
        self.site_root = Path(mapping_file).parent.parent
    
    def resolve_link_target(self, link, source_file):
        """Resolve where a link points to (old_rel_path format)"""
        if link.startswith(('http://', 'https://', '#', 'mailto:', 'tel:', 'javascript:', 'data:')):
            return None
        
        # Remove query string
        link_path = link.split('?')[0] if '?' in link else link
        
        # Absolute link
        if link_path.startswith('/'):
            return None
        
        # Resolve relative to source file directory
        source_dir = Path(source_file).parent
        try:
            target = (source_dir / link_path).resolve()
            target_rel = str(target.relative_to(self.site_root))
            return target_rel
        except (ValueError, RuntimeError):
            return None
    
    def transform_link(self, link, old_source_rel, new_source_rel):
        """Transform link from old page location to new page location"""
        if link.startswith(('http://', 'https://', '#', 'mailto:', 'tel:', 'javascript:', 'data:')):
            return link
        
        # Preserve query string
        query_str = ''
        if '?' in link:
            link_path, query_str = link.split('?', 1)
            query_str = '?' + query_str
        else:
            link_path = link
        
        # Absolute link - no change
        if link_path.startswith('/'):
            return link
        
        # Resolve link target in old structure
        old_source_dir = Path(old_source_rel).parent
        target_in_old = old_source_dir / link_path
        target_norm = target_in_old.resolve()
        
        # Get target in new structure
        target_rel_old = str(target_norm.relative_to(self.site_root))
        target_rel_new = self.mapping.get(target_rel_old, target_rel_old)
        
        # Calculate relative link from new source location
        new_source_dir = Path(new_source_rel).parent
        try:
            new_link = str(Path(target_rel_new).relative_to(new_source_dir))
        except ValueError:
            new_link = link_path
        
        return new_link + query_str
    
    def fix_html_with_lxml(self, html_content, old_source_rel, new_source_rel):
        """Use lxml to rewrite all href/src attributes"""
        try:
            doc = lxml_html.fromstring(html_content, lxml_html.HTMLParser())
        except Exception as e:
            # Fallback: use fallback method
            return self.fix_html_with_regex(html_content, old_source_rel, new_source_rel)
        
        # Find all elements with href or src
        for elem in doc.iter():
            for attr in ['href', 'src']:
                old_link = elem.get(attr)
                if old_link:
                    new_link = self.transform_link(old_link, old_source_rel, new_source_rel)
                    if new_link != old_link:
                        elem.set(attr, new_link)
        
        return lxml_html.tostring(doc, encoding='unicode', method='html')
    
    def fix_html_with_regex(self, html_content, old_source_rel, new_source_rel):
        """Fallback: use regex to rewrite links"""
        def replace_attr(match):
            tag = match.group(1)
            attr = match.group(2)
            old_link = match.group(3)
            rest = match.group(4)
            new_link = self.transform_link(old_link, old_source_rel, new_source_rel)
            return f'<{tag} {attr}="{new_link}"{rest}>'
        
        pattern = r'<(\w+[^>]*)\s(href|src)="([^"]*)"([^>]*)>'
        return re.sub(pattern, replace_attr, html_content)
    
    def process_site(self, site_path, old_structure_root, new_structure_root):
        """Process all HTML files in site"""
        site_root = Path(site_path)
        fixed_count = 0
        error_count = 0
        
        for new_html_file in sorted(site_root.rglob('*.html')):
            try:
                # Determine old file path
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
                
                # Fix links
                if HAS_LXML:
                    fixed_html = self.fix_html_with_lxml(html_content, old_rel, new_rel)
                else:
                    fixed_html = self.fix_html_with_regex(html_content, old_rel, new_rel)
                
                # Write back
                with open(new_html_file, 'w', encoding='utf-8') as f:
                    f.write(fixed_html)
                
                fixed_count += 1
            
            except Exception as e:
                print(f"⚠️  Error processing {new_html_file}: {e}", file=sys.stderr)
                error_count += 1
        
        return fixed_count, error_count


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 fix-links.py <site_path> [path_mapping_file]")
        sys.exit(1)
    
    site_path = sys.argv[1]
    mapping_file = sys.argv[2] if len(sys.argv) > 2 else str(Path(site_path) / 'path-mapping.json')
    
    site_root = Path(site_path)
    if not site_root.exists():
        print(f"❌ Path not found: {site_path}")
        sys.exit(1)
    
    if not Path(mapping_file).exists():
        print(f"❌ Mapping file not found: {mapping_file}")
        print(f"   Run: normalize-paths.py {site_path}")
        sys.exit(1)
    
    print(f"🔧 Fixing links using {'lxml' if HAS_LXML else 'regex'}...")
    print(f"   Site: {site_path}")
    print(f"   Mapping: {mapping_file}")
    
    rewriter = LinkRewriter(mapping_file)
    fixed_count, error_count = rewriter.process_site(site_path, site_path, site_path)
    
    print(f"\n✅ Fixed {fixed_count} files")
    if error_count > 0:
        print(f"⚠️  Errors: {error_count}")
        sys.exit(1)
    else:
        sys.exit(0)


if __name__ == '__main__':
    main()
