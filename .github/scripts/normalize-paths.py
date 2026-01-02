#!/usr/bin/env python3
"""
Calculate path mappings for HTML restructuring
Maps: old_path -> new_path for all files
Used by fix-links.py to rewrite href/src attributes
"""
import json
from pathlib import Path
from urllib.parse import urljoin


def calculate_path_mapping(site_root):
    """Build {old_rel_path: new_rel_path} mapping for all HTML files"""
    mapping = {}
    site_root = Path(site_root)
    
    for old_file in sorted(site_root.rglob('*.html')):
        old_rel = str(old_file.relative_to(site_root))
        
        # Convert: page.html -> page/index.html
        if old_file.name == 'index.html':
            new_rel = old_rel
        else:
            # Remove .html, add /index.html
            stem = old_file.stem
            parent = old_file.parent.relative_to(site_root)
            new_rel = str(parent / stem / 'index.html') if parent != Path('.') else f"{stem}/index.html"
        
        mapping[old_rel] = new_rel
    
    return mapping


def calculate_depth_change(old_path, new_path):
    """Calculate depth change: page.html (depth 1) -> page/index.html (depth 2)"""
    old_depth = len(Path(old_path).parts)
    new_depth = len(Path(new_path).parts)
    return new_depth - old_depth


def get_relative_link_transform(old_path, new_path, link, mapping):
    """
    Transform a link when file moves from old_path to new_path
    
    Example:
        old: book-a-callout.html -> link "services" -> ../services/
        new: book-a-callout/index.html -> link should be "../../services/"
    """
    if link.startswith(('http://', 'https://', '#', 'mailto:', 'tel:', 'javascript:', 'data:')):
        return link
    
    # Parse query string
    if '?' in link:
        link_path, query = link.split('?', 1)
        query_str = '?' + query
    else:
        link_path = link
        query_str = ''
    
    # Absolute link (no transform needed)
    if link_path.startswith('/'):
        return link
    
    # Resolve link relative to old location
    old_dir = Path(old_path).parent
    target_abs = old_dir / link_path
    target_norm = target_abs.resolve()
    
    # Find what file it points to
    target_rel = str(target_norm.relative_to(Path(old_path).parent.parent))
    
    # Get new location
    new_dir = Path(new_path).parent
    
    # Calculate relative path from new location
    try:
        new_link = str(Path(target_rel).relative_to(new_dir))
    except ValueError:
        new_link = link_path
    
    return new_link + query_str


def main():
    import sys
    
    if len(sys.argv) < 2:
        print("Usage: python3 normalize-paths.py <site_path>")
        sys.exit(1)
    
    site_path = sys.argv[1]
    site_root = Path(site_path)
    
    if not site_root.exists():
        print(f"❌ Path not found: {site_path}")
        sys.exit(1)
    
    print(f"📊 Calculating path mappings for {site_path}...")
    mapping = calculate_path_mapping(site_root)
    
    # Save mapping
    output_file = site_root / 'path-mapping.json'
    with open(output_file, 'w') as f:
        json.dump(mapping, f, indent=2)
    
    print(f"✅ Mapped {len(mapping)} files")
    print(f"📁 Mapping saved to: {output_file}")
    
    # Show sample
    for i, (old, new) in enumerate(list(mapping.items())[:5]):
        depth_change = calculate_depth_change(old, new)
        print(f"   {old} → {new} (depth +{depth_change})")
    
    if len(mapping) > 5:
        print(f"   ... and {len(mapping) - 5} more")


if __name__ == '__main__':
    main()
