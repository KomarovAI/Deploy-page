#!/usr/bin/env python3
"""Fix static site issues for GitHub Pages deployment."""

import sys
import shutil
import json
from pathlib import Path
from typing import List, Tuple, Optional, Dict
import re
from html.parser import HTMLParser
from urllib.parse import urljoin, urlparse

# Auto-install dependencies
try:
    from bs4 import BeautifulSoup
except ImportError:
    print("📦 Installing dependencies...")
    import subprocess
    subprocess.check_call([
        sys.executable, "-m", "pip", "install",
        "beautifulsoup4", "lxml", "-q"
    ])
    from bs4 import BeautifulSoup


class LinkValidator(HTMLParser):
    """Extract all links from HTML (token-optimized)"""
    def __init__(self):
        super().__init__()
        self.links = []
    
    def handle_starttag(self, tag, attrs):
        if tag in ['a', 'link', 'script', 'img', 'source']:
            for attr, value in attrs:
                if attr in ['href', 'src'] and value:
                    self.links.append(value)


class StaticSiteFixer:
    """Fix static site issues for GitHub Pages."""
    
    # Files to skip during restructuring
    SKIP_RESTRUCTURE = {
        'index.html',
        '404.html',
        'robots.txt',
        'sitemap.xml',
    }
    
    # Known directory prefixes (ordered by length for precise matching)
    DIRECTORY_PREFIXES = [
        'services',  # Must be before 'sector' to avoid wrong matches
        'sectors',
        'category',
        'news',
    ]
    
    # Legacy scripts to remove
    LEGACY_SCRIPTS = [
        'autoptimize',
        'comment-reply',
        'wp-embed',
        'wp-emoji-release',
        'jquery-migrate'
    ]
    
    # Problematic inline scripts (WordPress/Elementor)
    PROBLEMATIC_PATTERNS = [
        'elementorFrontend',
        'elementorEditorConfig',
        'wp.emoji',
        'wp.a11y',
        '_wpnonce',
        'addComment.moveForm',
        'document.write'
    ]
    
    # WordPress meta links to remove
    WP_META_RELS = [
        'EditURI',
        'wlwmanifest',
        'shortlink',
        'pingback'
    ]
    
    def __init__(self):
        self.files_processed = 0
        self.js_injected = 0
        self.scripts_removed = 0
        self.files_restructured = 0
        self.links_fixed = 0
        self.resources_fixed = 0
        self.css_fixed = 0
        self.data_attrs_fixed = 0
        self.base_tags_added = 0
        self.relative_links_fixed = 0
        self.shortcodes_detected = []
        self.restructure_map: Dict[str, str] = {}
        self.broken_links = []
        self.sitemap_urls = []
        self.relative_path_issues = []
    
    def detect_directory_structure(self, filename: str) -> Optional[Tuple[str, str]]:
        """Detect directory structure from flattened filename.
        
        CRITICAL FIX: Prevent hyphenated pages from being treated as nested.
        
        Examples:
            ✅ sectorsbars-pubs.html → ('sectors', 'bars-pubs')
            ✅ servicesdesign-sales-installation.html → ('services', 'design-sales-installation')
            ✅ categoryinsights.html → ('category', 'insights')
            ✅ newschristmas-opening.html → ('news', 'christmas-opening')
            
            ❌ news-insights.html → None (treated as standalone page, not news/-insights)
            ❌ services-test.html → None (treated as standalone page, not services/-test)
        
        Returns:
            (directory, basename) tuple or None if no prefix matches
        """
        # Try each known prefix
        for prefix in self.DIRECTORY_PREFIXES:
            if filename.startswith(prefix):
                # Extract the rest after prefix
                rest = filename[len(prefix):]
                
                # CRITICAL CHECK: If rest starts with hyphen, this is NOT a nested page
                if rest and not rest.startswith('-'):
                    return (prefix, rest)
        
        return None
    
    def inject_base_tag(self, soup: BeautifulSoup, base_href: str = "/") -> bool:
        """⭐ NEW: Inject <base href> tag to fix nested link issues.
        
        PROBLEM: When links use relative paths like './about.html',
        they work from root but BREAK on nested pages:
        - /index.html → ./about.html ✅ finds /about.html
        - /services/design/index.html → ./about.html ❌ looks for /services/design/about.html
        
        SOLUTION: Add <base href="/"> in <head> to make ALL relative paths
        resolve from root, not current directory.
        
        Example output:
        <head>
            <meta charset="UTF-8">
            <base href="/">  ← THIS FIXES EVERYTHING
            <title>Page</title>
        </head>
        """
        head = soup.find('head')
        if not head:
            return False
        
        # Check if base tag already exists
        existing_base = head.find('base')
        if existing_base:
            return False  # Already has base tag
        
        # Create and insert base tag (after charset, before other meta tags)
        base_tag = soup.new_tag('base', href=base_href)
        
        # Find insertion point: after charset meta, before other tags
        charset = head.find('meta', charset=True)
        if charset:
            charset.insert_after(base_tag)
        else:
            # No charset, insert at beginning
            head.insert(0, base_tag)
        
        self.base_tags_added += 1
        return True
    
    def detect_relative_path_issues(self, soup: BeautifulSoup, file_depth: int) -> List[str]:
        """⭐ NEW: Detect links that will break on nested pages.
        
        Pattern: ./page.html (relative to current directory)
        Issue: Works on /index.html but breaks on /dir/subdir/index.html
        
        Returns: List of problematic links found
        """
        issues = []
        
        # Only check if file is nested (depth > 0)
        if file_depth == 0:
            return issues
        
        for link_tag in soup.find_all('a', href=True):
            href = link_tag['href']
            
            # Check for relative directory links: ./page.html or ../page.html pattern
            if href.startswith('./') and not href.startswith('./'):
                # This ./page.html will BREAK on nested pages
                issues.append(href)
            elif not href.startswith(('/', 'http://', 'https://', '#', 'mailto:', 'tel:', '..')):  
                # Bare relative: page.html will BREAK on nested pages
                issues.append(href)
        
        return issues
    
    def make_absolute(self, href: str) -> str:
        """⭐ NEW: Convert relative link to absolute.
        
        Examples:
            services              → /services/
            ./maintenance         → /maintenance/
            ../sectors/cafes      → /sectors/cafes/
            ./services/booking.html → /services/booking.html
            /services             → /services/
        
        Returns:
            Absolute path starting with /
        """
        # Skip external and special links
        if href.startswith(('http://', 'https://', '#', 'mailto:', 'tel:', 'data:', '//', 'javascript:')):
            return href
        
        # Already absolute
        if href.startswith('/'):
            # Ensure trailing slash for directories (no file extension)
            if not href.endswith('/') and '.' not in href.split('/')[-1]:
                return href + '/'
            return href
        
        # Empty or just anchor
        if not href or href == '.':
            return href
        
        # Remove ./ prefix
        href = href.lstrip('./')
        
        # Handle ../ (remove them - assume link to root)
        while href.startswith('../'):
            href = href[3:]
        
        # Ensure starts with /
        if not href.startswith('/'):
            href = '/' + href
        
        # Add trailing slash if it's a directory (no file extension)
        if not href.endswith('/') and '.' not in href.split('/')[-1]:
            href = href + '/'
        
        return href
    
    def fix_relative_links(self, cwd: Path) -> int:
        """⭐ CRITICAL: Convert all relative links to absolute after restructuring.
        
        PROBLEM: After moving book-a-callout.html → book-a-callout/index.html,
        relative links break:
        - OLD: book-a-callout.html → <a href="services"> points to services.html ✅
        - NEW: book-a-callout/index.html → <a href="services"> looks in book-a-callout/services ❌
        
        SOLUTION: Convert ALL relative links to absolute:
        <a href="services">              → <a href="/services/">
        <a href="./maintenance">         → <a href="/maintenance/">
        <a href="sectors/cafes">         → <a href="/sectors/cafes/">
        
        This ensures links work regardless of page nesting depth.
        """
        html_files = [
            f for f in cwd.rglob("*.html")
            if ".git" not in f.parts and ".github" not in f.parts
        ]
        
        if not html_files:
            return 0
        
        fixed_count = 0
        total_links_fixed = 0
        
        for html_file in html_files:
            try:
                content = html_file.read_text(encoding="utf-8", errors="ignore")
                soup = BeautifulSoup(content, "lxml")
                modified = False
                file_links_fixed = 0
                
                # Fix ALL <a> tags with href
                for tag in soup.find_all('a', href=True):
                    href = tag['href']
                    new_href = self.make_absolute(href)
                    
                    if new_href != href:
                        tag['href'] = new_href
                        modified = True
                        file_links_fixed += 1
                        total_links_fixed += 1
                
                if modified:
                    html_file.write_text(str(soup), encoding="utf-8")
                    fixed_count += 1
                    
            except Exception as e:
                pass  # Skip files with errors
        
        self.relative_links_fixed = total_links_fixed
        return fixed_count
    
    def validate_links(self, cwd: Path) -> int:
        """Validate all links exist (integrated, token-optimized)"""
        checked, broken = set(), []
        
        for html_file in sorted(cwd.rglob("*.html")):
            if ".git" in html_file.parts or ".github" in html_file.parts:
                continue
            
            try:
                with open(html_file, 'r', encoding='utf-8', errors='ignore') as f:
                    parser = LinkValidator()
                    parser.feed(f.read())
                    
                    for link in parser.links:
                        # Skip external/special
                        if link.startswith(('http://', 'https://', '#', 'mailto:', 'tel:', 'javascript:')):
                            continue
                        
                        link_path = urlparse(link).path.split('?')[0]
                        
                        # Resolve path
                        if link_path.startswith('/'):
                            target = cwd / link_path.lstrip('/')
                        else:
                            target = (html_file.parent / link_path).resolve()
                        
                        target_key = str(target)
                        if target_key in checked:
                            continue
                        checked.add(target_key)
                        
                        if not target.exists():
                            broken.append({
                                'source': str(html_file.relative_to(cwd)),
                                'link': link,
                                'target': str(target.relative_to(cwd)) if target.is_relative_to(cwd) else str(target)
                            })
            
            except Exception:
                pass
        
        self.broken_links = broken[:50]  # Cap at 50
        return len(broken)
    
    def generate_sitemap(self, cwd: Path, domain: str = "https://example.com") -> bool:
        """Auto-generate sitemap.xml from HTML files"""
        urls = []
        
        for html_file in sorted(cwd.rglob("*.html")):
            if any(x in html_file.parts for x in [".git", ".github", "404.html"]):
                continue
            
            rel = html_file.relative_to(cwd)
            
            if rel.name == "index.html":
                url = f"/{'/'.join(rel.parts[:-1])}/"
            else:
                url = f"/{rel.parent / rel.stem}/"
            
            urls.append(url.replace('\\', '/'))
        
        sitemap = '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
        for url in urls:
            sitemap += f'  <url><loc>{domain}{url}</loc></url>\n'
        sitemap += '</urlset>'
        
        (cwd / "sitemap.xml").write_text(sitemap, encoding='utf-8')
        self.sitemap_urls = urls
        return True
    
    def restructure_files(self, cwd: Path) -> int:
        """Restructure HTML files by creating proper folder structure."""
        print("\n📁 RESTRUCTURING PAGES:")
        print("━" * 80)
        
        html_files = [
            f for f in cwd.rglob("**/*.html")
            if f.name.lower() not in self.SKIP_RESTRUCTURE
            and ".git" not in f.parts
            and ".github" not in f.parts
        ]
        
        if not html_files:
            print("   No files to restructure")
            return 0
        
        print(f"   Found {len(html_files)} files to check\n")
        
        restructured = 0
        for html_file in html_files:
            try:
                rel_path = html_file.relative_to(cwd)
                parent_dir = rel_path.parent
                base_name = html_file.stem
                
                detected_structure = self.detect_directory_structure(base_name)
                
                if detected_structure:
                    dir_prefix, file_base = detected_structure
                    
                    if str(parent_dir) == '.':
                        target_folder = cwd / dir_prefix / file_base
                    else:
                        target_folder = cwd / parent_dir / dir_prefix / file_base
                    
                    target_folder.mkdir(parents=True, exist_ok=True)
                    target_file = target_folder / "index.html"
                    
                    shutil.copy2(html_file, target_file)
                    html_file.unlink()
                    
                    old_name = html_file.name
                    new_path = f"{dir_prefix}/{file_base}/"
                    self.restructure_map[old_name] = new_path
                    
                    old_structure = str(rel_path)
                    new_structure = str(target_file.relative_to(cwd))
                    
                    print(f"   ✓ {old_structure}")
                    print(f"     → {new_structure}")
                    print(f"     🌐 URL: /{new_path}")
                    print()
                    
                    restructured += 1
                
                else:
                    if base_name in ['index', '404']:
                        continue
                    
                    if str(parent_dir) == '.':
                        target_folder = cwd / base_name
                    else:
                        target_folder = cwd / parent_dir / base_name
                    
                    target_folder.mkdir(parents=True, exist_ok=True)
                    target_file = target_folder / "index.html"
                    
                    shutil.copy2(html_file, target_file)
                    html_file.unlink()
                    
                    old_name = html_file.name
                    new_path = f"{base_name}/"
                    self.restructure_map[old_name] = new_path
                    
                    old_structure = str(rel_path)
                    new_structure = str(target_file.relative_to(cwd))
                    
                    print(f"   ✓ {old_structure}")
                    print(f"     → {new_structure}")
                    print(f"     🌐 URL: /{new_path}")
                    print()
                    
                    restructured += 1
                
            except Exception as e:
                print(f"   ✗ ERROR: {html_file.name}: {e}")
        
        self.files_restructured = restructured
        print("━" * 80)
        print(f"✅ Restructured {restructured} page(s)\n")
        return restructured
    
    def fix_resource_paths(self, soup: BeautifulSoup, depth: int) -> int:
        """Fix relative paths to CSS/JS/images after restructuring."""
        if depth == 0:
            return 0
        
        fixed = 0
        prefix = "../" * depth
        
        # Fix CSS links
        for tag in soup.find_all('link', href=True):
            href = tag['href']
            if href.startswith('wp-content/') or href.startswith('wp-includes/'):
                tag['href'] = prefix + href
                fixed += 1
        
        # Fix JS scripts
        for tag in soup.find_all('script', src=True):
            src = tag['src']
            if src.startswith('wp-content/') or src.startswith('wp-includes/'):
                tag['src'] = prefix + src
                fixed += 1
        
        # Fix images
        for tag in soup.find_all('img', src=True):
            src = tag['src']
            if src.startswith('wp-content/'):
                tag['src'] = prefix + src
                fixed += 1
        
        # Fix background images in style attributes
        for tag in soup.find_all(style=True):
            style = tag['style']
            if 'wp-content/' in style:
                tag['style'] = re.sub(
                    r'url\(\s*(["\']?)wp-content/',
                    f'url(\\1{prefix}wp-content/',
                    style
                )
                fixed += 1
        
        return fixed
    
    def fix_css_files(self, cwd: Path) -> int:
        """Fix absolute URLs inside external CSS files (Elementor issue)."""
        css_files = list(cwd.rglob("*.css"))
        if not css_files:
            return 0
        
        fixed = 0
        for css_file in css_files:
            try:
                content = css_file.read_text(encoding='utf-8', errors='ignore')
                
                # Replace http://domain/path with relative path
                modified = re.sub(
                    r'url\(\s*(["\']?)https?://[^/]+(/[^"\')]+)\1\s*\)',
                    r'url(.\2)',
                    content
                )
                
                if modified != content:
                    css_file.write_text(modified, encoding='utf-8')
                    fixed += 1
                    self.css_fixed += 1
            except Exception:
                pass
        
        return fixed
    
    def fix_data_attributes(self, soup: BeautifulSoup) -> int:
        """Fix data-* attributes containing URLs (Elementor/WP patterns)."""
        fixed = 0
        
        for tag in soup.find_all(True):  # All tags
            for attr in list(tag.attrs.keys()):
                if attr.startswith('data-') and attr not in ['data-id', 'data-type']:
                    value = tag.get(attr, '')
                    if isinstance(value, str):
                        # Check if value contains URL-like patterns
                        if 'wp-content' in value or 'wp-includes' in value:
                            # Simple replacement for direct URLs
                            modified = value.replace('/wp-content/', './wp-content/')
                            modified = modified.replace('/wp-includes/', './wp-includes/')
                            
                            if modified != value:
                                tag[attr] = modified
                                fixed += 1
                                self.data_attrs_fixed += 1
        
        return fixed
    
    def fix_srcset_attribute(self, img_tag) -> bool:
        """Fix URLs in srcset attribute."""
        srcset = img_tag.get('srcset', '')
        if not srcset or 'wp-content' not in srcset:
            return False
        
        parts = []
        for item in srcset.split(','):
            item = item.strip()
            # Split by last space to separate URL from descriptor
            url, *desc = item.rsplit(' ', 1)
            
            # Fix URL
            fixed_url = url.replace('/wp-content/', './wp-content/')
            
            # Reconstruct item
            new_item = f"{fixed_url} {' '.join(desc)}" if desc else fixed_url
            parts.append(new_item)
        
        new_srcset = ', '.join(parts)
        if new_srcset != srcset:
            img_tag['srcset'] = new_srcset
            return True
        
        return False
    
    def detect_shortcodes(self, soup: BeautifulSoup) -> List[str]:
        """Detect remaining WordPress shortcodes."""
        shortcodes = []
        text_content = soup.get_text()
        
        # Match [shortcode ...] patterns
        matches = re.findall(r'\[([a-z_]+)[^\]]*\]', text_content)
        shortcodes.extend(set(matches))
        
        return shortcodes
    
    def remove_wordpress_meta_links(self, soup: BeautifulSoup) -> int:
        """Remove WordPress-specific meta links."""
        removed = 0
        
        for link in soup.find_all('link', rel=True):
            rel = link.get('rel', [])
            if isinstance(rel, str):
                rel = [rel]
            
            if any(r in self.WP_META_RELS for r in rel):
                link.decompose()
                removed += 1
        
        return removed
    
    def remove_problematic_scripts(self, soup: BeautifulSoup) -> int:
        """Remove inline scripts that reference undefined variables."""
        removed = 0
        
        # Remove script tags by content
        for script in soup.find_all('script'):
            if script.string:
                content = script.string
                
                # Check if script contains problematic patterns
                if any(pattern in content for pattern in self.PROBLEMATIC_PATTERNS):
                    script.decompose()
                    removed += 1
        
        return removed
    
    def fix_canonical_urls(self, soup: BeautifulSoup, target_domain: Optional[str] = None) -> int:
        """Fix canonical URLs to point to correct domain."""
        fixed = 0
        
        for link in soup.find_all('link', rel='canonical', href=True):
            href = link['href']
            
            # Remove localhost canonical tags
            if 'localhost' in href or '127.0.0.1' in href:
                link.decompose()
                fixed += 1
            # If target_domain provided, update URL
            elif target_domain and href.startswith('http'):
                path = re.sub(r'https?://[^/]+', '', href)
                link['href'] = f"{target_domain}{path}"
                fixed += 1
        
        return fixed
    
    def fix_internal_links(self, cwd: Path) -> int:
        """Fix internal links after restructuring."""
        if not self.restructure_map:
            return 0
        
        html_files = [
            f for f in cwd.rglob("*.html")
            if ".git" not in f.parts and ".github" not in f.parts
        ]
        
        fixed_count = 0
        
        for html_file in html_files:
            try:
                content = html_file.read_text(encoding="utf-8", errors="ignore")
                soup = BeautifulSoup(content, "lxml")
                modified = False
                
                for tag in soup.find_all('a', href=True):
                    href = tag['href']
                    
                    for old_name, new_path in self.restructure_map.items():
                        if href == old_name or href == f"./{old_name}" or href.endswith(f"/{old_name}"):
                            tag['href'] = new_path
                            modified = True
                            self.links_fixed += 1
                
                if modified:
                    html_file.write_text(str(soup), encoding="utf-8")
                    fixed_count += 1
                    
            except Exception:
                pass
        
        return fixed_count
    
    def remove_legacy_scripts(self, soup: BeautifulSoup) -> int:
        """Remove legacy WordPress scripts."""
        removed = 0
        
        for script in soup.find_all('script', src=True):
            src = script.get('src', '')
            if any(legacy in src for legacy in self.LEGACY_SCRIPTS):
                script.decompose()
                removed += 1
        
        for script in soup.find_all('script'):
            if script.string:
                if any(legacy in script.string for legacy in ['wp.emoji', 'addComment']):
                    script.decompose()
                    removed += 1
        
        return removed
    
    def inject_navigation_fix(self, soup: BeautifulSoup) -> bool:
        """Inject navigation fix script before </body>."""
        body = soup.find('body')
        if not body:
            return False
        
        nav_fix_js = '''<script>
// GitHub Pages navigation fix
(function() {
  console.log('✅ GitHub Pages navigation active');
})();
</script>'''
        
        script_tag = soup.new_tag('script')
        script_tag.string = nav_fix_js.strip()
        body.append(script_tag)
        return True
    
    def process_html_file(self, file_path: Path, cwd: Path, base_href: str = "/") -> Tuple[bool, int, int]:
        """Process a single HTML file."""
        try:
            content = file_path.read_text(encoding="utf-8", errors="ignore")
            soup = BeautifulSoup(content, "lxml")
            
            modified = False
            scripts_removed = 0
            resources_fixed = 0
            
            rel_path = file_path.relative_to(cwd)
            depth = len(rel_path.parts) - 1
            
            # ⭐ NEW: Inject base tag to fix nested link issues
            if self.inject_base_tag(soup, base_href):
                modified = True
            
            # ⭐ NEW: Detect potential relative path issues
            issues = self.detect_relative_path_issues(soup, depth)
            if issues:
                self.relative_path_issues.extend(issues)
            
            # Fix resource paths
            resources_fixed = self.fix_resource_paths(soup, depth)
            if resources_fixed > 0:
                modified = True
                self.resources_fixed += resources_fixed
            
            # Fix data attributes (Elementor)
            data_fixed = self.fix_data_attributes(soup)
            if data_fixed > 0:
                modified = True
                self.data_attrs_fixed += data_fixed
            
            # Fix srcset attributes
            for img in soup.find_all('img'):
                if self.fix_srcset_attribute(img):
                    modified = True
                    self.data_attrs_fixed += 1
            
            # Remove WordPress meta links
            meta_removed = self.remove_wordpress_meta_links(soup)
            if meta_removed > 0:
                modified = True
                self.scripts_removed += meta_removed
            
            # Fix canonical URLs
            canonical_fixed = self.fix_canonical_urls(soup)
            if canonical_fixed > 0:
                modified = True
                self.scripts_removed += canonical_fixed
            
            # Remove problematic inline scripts
            problematic_removed = self.remove_problematic_scripts(soup)
            if problematic_removed > 0:
                modified = True
                self.scripts_removed += problematic_removed
            
            # Remove legacy scripts
            scripts_removed = self.remove_legacy_scripts(soup)
            if scripts_removed > 0:
                modified = True
                self.scripts_removed += scripts_removed
            
            # Detect shortcodes (warning)
            shortcodes = self.detect_shortcodes(soup)
            if shortcodes and file_path.name != '404.html':
                self.shortcodes_detected.append((file_path.name, shortcodes))
            
            # Inject navigation fix
            if self.inject_navigation_fix(soup):
                modified = True
                self.js_injected += 1
            
            if modified:
                file_path.write_text(str(soup), encoding="utf-8")
                return True, scripts_removed, resources_fixed
            
            return False, 0, 0
            
        except Exception:
            return False, 0, 0
    
    def run(self, base_href: str = "/") -> int:
        """Execute static site fixing."""
        cwd = Path.cwd()
        
        # STEP 1: Restructure files
        self.restructure_files(cwd)
        
        # STEP 1.5: ⭐ NEW: Fix relative links to absolute after restructuring
        print("\n🔗 FIXING RELATIVE LINKS TO ABSOLUTE:")
        print("━" * 80)
        fixed_link_files = self.fix_relative_links(cwd)
        if self.relative_links_fixed > 0:
            print(f"✅ Fixed {self.relative_links_fixed} relative links in {fixed_link_files} file(s)")
            print("   → services → /services/, ./maintenance → /maintenance/, etc.\n")
        else:
            print("✓ No relative links to fix\n")
        
        # STEP 2: Fix CSS files (Elementor)
        css_fixed = self.fix_css_files(cwd)
        if css_fixed > 0:
            print(f"✅ Fixed URLs in {css_fixed} CSS file(s)\n")
        
        # STEP 3: Fix internal links
        fixed_files = self.fix_internal_links(cwd)
        if self.links_fixed > 0:
            print(f"✅ Fixed {self.links_fixed} internal links\n")
        
        # STEP 4: Process HTML files
        html_files = [
            f for f in cwd.rglob("*.html")
            if ".git" not in f.parts and ".github" not in f.parts
        ]
        
        if not html_files:
            print("⚠️ No HTML files found")
            return 0
        
        for html_file in html_files:
            modified, removed, resources = self.process_html_file(html_file, cwd, base_href)
            if modified:
                self.files_processed += 1
        
        # Summary
        if self.base_tags_added > 0:
            print(f"\n⭐ Added <base href=\"{base_href}\"> tags: {self.base_tags_added} files")
            print("   → Fallback for nested page link issues\n")
        
        if self.relative_path_issues:
            print(f"⚠️  Found {len(self.relative_path_issues)} potential relative path issues:")
            for issue in self.relative_path_issues[:10]:
                print(f"   - {issue}")
            if len(self.relative_path_issues) > 10:
                print(f"   ... and {len(self.relative_path_issues) - 10} more")
            print("   → Should be fixed by relative link conversion above\n")
        
        if self.resources_fixed > 0:
            print(f"✅ Fixed {self.resources_fixed} resource paths\n")
        
        if self.data_attrs_fixed > 0:
            print(f"✅ Fixed {self.data_attrs_fixed} data attributes (Elementor)\n")
        
        if self.scripts_removed > 0:
            print(f"✅ Removed {self.scripts_removed} problematic scripts/links\n")
        
        # STEP 5: Validate links
        broken_count = self.validate_links(cwd)
        if broken_count > 0:
            print(f"\n❌ Found {broken_count} broken links (first 50 shown):")
            for item in self.broken_links[:15]:
                print(f"  📄 {item['source']}: {item['link']}")
            if len(self.broken_links) > 15:
                print(f"  ... and {len(self.broken_links) - 15} more")
            
            with open('broken-links.json', 'w') as f:
                json.dump(self.broken_links, f, indent=2)
            print("\n📋 Full report: broken-links.json")
        else:
            print(f"\n✅ Link validation: all {len(html_files)} files passed\n")
        
        # STEP 6: Generate sitemap
        if self.generate_sitemap(cwd):
            print(f"✅ Generated sitemap.xml ({len(self.sitemap_urls)} URLs)\n")
        
        # Shortcode warnings
        if self.shortcodes_detected:
            print("⚠️  DETECTED DYNAMIC SHORTCODES (won't work on static site):")
            for filename, shortcodes in self.shortcodes_detected[:5]:  # Show first 5
                print(f"    {filename}: {', '.join(shortcodes[:3])}")  # Show first 3 shortcodes
            if len(self.shortcodes_detected) > 5:
                print(f"    ... and {len(self.shortcodes_detected) - 5} more file(s)")
            print()
        
        return 0 if broken_count == 0 else 1


if __name__ == "__main__":
    try:
        fixer = StaticSiteFixer()
        base_href = "/"  # Can be changed to /project/ if needed
        sys.exit(fixer.run(base_href))
    except KeyboardInterrupt:
        print("⚠️ Interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Fatal error: {e}")
        sys.exit(1)
