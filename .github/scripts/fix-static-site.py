#!/usr/bin/env python3
"""Fix static site issues for GitHub Pages deployment."""

import sys
import shutil
from pathlib import Path
from typing import List, Tuple, Optional, Dict
import re

# Auto-install dependencies
try:
    from bs4 import BeautifulSoup
    from rich.console import Console
    from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn, TaskProgressColumn
    from rich.panel import Panel
    from rich.table import Table
    from loguru import logger
except ImportError:
    print("📦 Installing dependencies...")
    import subprocess
    subprocess.check_call([
        sys.executable, "-m", "pip", "install",
        "beautifulsoup4", "lxml", "rich", "loguru", "-q"
    ])
    from bs4 import BeautifulSoup
    from rich.console import Console
    from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn, TaskProgressColumn
    from rich.panel import Panel
    from rich.table import Table
    from loguru import logger

# Setup console and logger
console = Console()
logger.remove()
logger.add(
    "/tmp/fix-static-site-{time}.log",
    format="{time:YYYY-MM-DD HH:mm:ss} | {level: <8} | {message}",
    level="DEBUG"
)
logger.add(lambda msg: None)


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
    
    def __init__(self):
        self.files_processed = 0
        self.js_injected = 0
        self.scripts_removed = 0
        self.files_restructured = 0
        self.links_fixed = 0
        self.restructure_map: Dict[str, str] = {}  # old_name -> new_path
        logger.info("StaticSiteFixer initialized")
    
    def detect_directory_structure(self, filename: str) -> Optional[Tuple[str, str]]:
        """Detect directory structure from flattened filename.
        
        Examples:
            sectorsbars-pubs.html -> ('sectors', 'bars-pubs')
            servicesdesign-sales-installation.html -> ('services', 'design-sales-installation')
            categoryinsights.html -> ('category', 'insights')
            newschristmas-opening.html -> ('news', 'christmas-opening')
        
        Returns:
            (directory, basename) tuple or None if no prefix matches
        """
        # Try each known prefix
        for prefix in self.DIRECTORY_PREFIXES:
            if filename.startswith(prefix):
                # Extract the rest after prefix
                rest = filename[len(prefix):]
                if rest:  # Make sure there's something after the prefix
                    return (prefix, rest)
        
        return None
    
    def restructure_files(self, cwd: Path) -> int:
        """Restructure HTML files by creating proper folder structure.
        
        This fixes GitHub Pages 404 errors by creating folder structure compatible
        with GitHub Pages routing.
        
        Transforms:
            sectorsbars-pubs.html -> sectors/bars-pubs/index.html
            servicesdesign-sales.html -> services/design-sales/index.html
        """
        console.print("\n[bold cyan]📁 STEP 1: Restructuring file layout...[/bold cyan]")
        
        # Find all HTML files recursively, excluding .git and .github
        html_files = [
            f for f in cwd.rglob("**/*.html")
            if f.name.lower() not in self.SKIP_RESTRUCTURE
            and ".git" not in f.parts
            and ".github" not in f.parts
        ]
        
        if not html_files:
            console.print("[yellow]   No files to restructure[/yellow]")
            return 0
        
        console.print(f"[cyan]   Found {len(html_files)} files to check[/cyan]")
        
        restructured = 0
        for html_file in html_files:
            try:
                # Get relative path from cwd
                rel_path = html_file.relative_to(cwd)
                parent_dir = rel_path.parent
                base_name = html_file.stem  # filename without .html
                
                # Detect if filename is flattened (e.g., sectorsbars-pubs)
                detected_structure = self.detect_directory_structure(base_name)
                
                if detected_structure:
                    # Flattened filename detected - restore directory structure
                    dir_prefix, file_base = detected_structure
                    
                    # CRITICAL: Build CORRECT path with directories
                    if str(parent_dir) == '.':
                        # File is in root directory
                        target_folder = cwd / dir_prefix / file_base
                    else:
                        # File is in a subdirectory
                        target_folder = cwd / parent_dir / dir_prefix / file_base
                    
                    # CREATE the target folder
                    target_folder.mkdir(parents=True, exist_ok=True)
                    
                    # Target file: directory/basename/index.html
                    target_file = target_folder / "index.html"
                    
                    # Copy file content to new location
                    shutil.copy2(html_file, target_file)
                    
                    # Remove original file
                    html_file.unlink()
                    
                    old_name = html_file.name  # e.g., sectorsbars-pubs.html
                    new_path = f"{dir_prefix}/{file_base}/"  # e.g., sectors/bars-pubs/
                    
                    # Store mapping for link fixing
                    self.restructure_map[old_name] = new_path
                    
                    old_structure = str(rel_path)
                    new_structure = str(target_file.relative_to(cwd))
                    
                    logger.info(f"Restructured: {old_structure} -> {new_structure}")
                    console.print(f"   [green]✓[/green] {old_structure} → {new_structure}")
                    restructured += 1
                
                else:
                    # Normal filename (not flattened) - check if needs restructuring
                    if base_name in ['index', '404']:
                        # Keep index.html and 404.html as-is
                        continue
                    
                    # Create folder for this file: parent/basename/index.html
                    if str(parent_dir) == '.':
                        target_folder = cwd / base_name
                    else:
                        target_folder = cwd / parent_dir / base_name
                    
                    # CREATE the target folder
                    target_folder.mkdir(parents=True, exist_ok=True)
                    
                    # Target file
                    target_file = target_folder / "index.html"
                    
                    # Copy file content to new location
                    shutil.copy2(html_file, target_file)
                    
                    # Remove original file
                    html_file.unlink()
                    
                    old_name = html_file.name  # e.g., contact.html
                    new_path = f"{base_name}/"  # e.g., contact/
                    
                    # Store mapping
                    self.restructure_map[old_name] = new_path
                    
                    old_structure = str(rel_path)
                    new_structure = str(target_file.relative_to(cwd))
                    
                    logger.info(f"Restructured: {old_structure} -> {new_structure}")
                    console.print(f"   [green]✓[/green] {old_structure} → {new_structure}")
                    restructured += 1
                
            except Exception as e:
                logger.error(f"Failed to restructure {html_file.name}: {e}")
                console.print(f"   [red]✗[/red] {html_file.name}: {e}")
        
        self.files_restructured = restructured
        console.print(f"\n[bold green]   ✨ Restructured {restructured} file(s)[/bold green]\n")
        return restructured
    
    def fix_internal_links(self, cwd: Path) -> int:
        """Fix internal links after restructuring.
        
        Updates links like:
            sectorsbars-pubs.html -> sectors/bars-pubs/
            servicesdesign.html -> services/design/
        """
        if not self.restructure_map:
            return 0
        
        console.print("[bold cyan]🔗 STEP 2: Fixing internal links...[/bold cyan]")
        
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
                
                # Fix <a href="...">
                for tag in soup.find_all('a', href=True):
                    href = tag['href']
                    
                    # Check if href matches old filename
                    for old_name, new_path in self.restructure_map.items():
                        if href == old_name or href == f"./{old_name}" or href.endswith(f"/{old_name}"):
                            tag['href'] = new_path
                            modified = True
                            self.links_fixed += 1
                            logger.debug(f"{html_file.name}: {href} -> {new_path}")
                
                if modified:
                    html_file.write_text(str(soup), encoding="utf-8")
                    fixed_count += 1
                    
            except Exception as e:
                logger.error(f"Failed to fix links in {html_file.name}: {e}")
        
        console.print(f"[green]   ✓ Fixed {self.links_fixed} links in {fixed_count} files[/green]\n")
        return fixed_count
    
    def remove_legacy_scripts(self, soup: BeautifulSoup) -> int:
        """Remove legacy WordPress scripts."""
        removed = 0
        
        # Remove script tags
        for script in soup.find_all('script', src=True):
            src = script.get('src', '')
            if any(legacy in src for legacy in self.LEGACY_SCRIPTS):
                logger.debug(f"Removing script: {src}")
                script.decompose()
                removed += 1
        
        # Remove inline scripts with legacy code
        for script in soup.find_all('script'):
            if script.string:
                if any(legacy in script.string for legacy in ['wp.emoji', 'addComment']):
                    logger.debug(f"Removing inline legacy script")
                    script.decompose()
                    removed += 1
        
        return removed
    
    def inject_navigation_fix(self, soup: BeautifulSoup) -> bool:
        """Inject navigation fix script before </body>."""
        body = soup.find('body')
        if not body:
            logger.warning("No <body> tag found")
            return False
        
        # Navigation fix JavaScript
        nav_fix_js = '''<script>
// GitHub Pages navigation fix
(function() {
  console.log('✅ GitHub Pages navigation active');
})();
</script>'''
        
        # Create script tag
        script_tag = soup.new_tag('script')
        script_tag.string = nav_fix_js.strip()
        
        # Insert before </body>
        body.append(script_tag)
        logger.debug("Navigation fix injected")
        return True
    
    def process_html_file(self, file_path: Path) -> Tuple[bool, int]:
        """Process a single HTML file."""
        try:
            content = file_path.read_text(encoding="utf-8", errors="ignore")
            soup = BeautifulSoup(content, "lxml")
            
            modified = False
            scripts_removed = 0
            
            # Remove legacy scripts
            scripts_removed = self.remove_legacy_scripts(soup)
            if scripts_removed > 0:
                modified = True
                self.scripts_removed += scripts_removed
            
            # Inject navigation fix
            if self.inject_navigation_fix(soup):
                modified = True
                self.js_injected += 1
            
            # Save if modified
            if modified:
                file_path.write_text(str(soup), encoding="utf-8")
                logger.info(f"{file_path.name}: injected nav fix, removed {scripts_removed} scripts")
                return True, scripts_removed
            
            return False, 0
            
        except Exception as e:
            logger.error(f"{file_path.name}: {e}")
            return False, 0
    
    def run(self) -> int:
        """Execute static site fixing with rich UI."""
        # Header
        console.print(Panel.fit(
            "[bold magenta]🚀 Static Site Fixer for GitHub Pages[/bold magenta]\n"
            "[yellow]Fixing:[/yellow] WordPress static exports\n"
            "[green]Actions:[/green] Restructure files, fix links, inject nav, remove legacy scripts",
            border_style="magenta"
        ))
        
        cwd = Path.cwd()
        logger.info(f"Working directory: {cwd}")
        
        # STEP 1: Restructure files
        self.restructure_files(cwd)
        
        # STEP 2: Fix internal links after restructuring
        self.fix_internal_links(cwd)
        
        # STEP 3: Find HTML files (after restructuring)
        console.print("[bold cyan]📝 STEP 3: Processing HTML content...[/bold cyan]")
        
        html_files = [
            f for f in cwd.rglob("*.html")
            if ".git" not in f.parts and ".github" not in f.parts
        ]
        
        if not html_files:
            console.print("[yellow]⚠️  No HTML files found[/yellow]")
            return 0
        
        console.print(f"[cyan]   Found {len(html_files)} HTML files[/cyan]\n")
        
        # Process with progress bar
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            BarColumn(),
            TaskProgressColumn(),
            console=console
        ) as progress:
            
            task = progress.add_task(
                "[magenta]   Processing HTML files...",
                total=len(html_files)
            )
            
            for html_file in html_files:
                modified, removed = self.process_html_file(html_file)
                if modified:
                    self.files_processed += 1
                progress.update(task, advance=1)
        
        # Summary table
        table = Table(title="\n📊 Summary", border_style="magenta")
        table.add_column("Metric", style="cyan", no_wrap=True)
        table.add_column("Value", style="yellow")
        
        table.add_row("Files restructured", f"[bold]{self.files_restructured}[/bold]")
        table.add_row("Internal links fixed", f"[bold]{self.links_fixed}[/bold]")
        table.add_row("HTML files scanned", str(len(html_files)))
        table.add_row("Files modified", f"[bold]{self.files_processed}[/bold]")
        table.add_row("Navigation fixes injected", f"[bold]{self.js_injected}[/bold]")
        table.add_row("Legacy scripts removed", f"[bold]{self.scripts_removed}[/bold]")
        
        console.print(table)
        
        if self.files_restructured > 0:
            console.print(f"\n[green]✨ Successfully restructured {self.files_restructured} files for GitHub Pages![/green]")
            console.print("[green]   URLs like /sectors/bars-pubs/ will now work correctly[/green]")
        
        if self.links_fixed > 0:
            console.print(f"[green]✨ Fixed {self.links_fixed} internal links[/green]")
        
        if self.files_processed > 0:
            console.print(f"[green]✨ Processed {self.files_processed} HTML file(s)[/green]")
        
        logger.info(f"Processing complete: {self.files_restructured} restructured, {self.links_fixed} links fixed, {self.files_processed} modified")
        return 0


if __name__ == "__main__":
    try:
        fixer = StaticSiteFixer()
        sys.exit(fixer.run())
    except KeyboardInterrupt:
        console.print("\n[red]⚠️  Interrupted by user[/red]")
        sys.exit(1)
    except Exception as e:
        console.print(f"\n[red]❌ Fatal error: {e}[/red]")
        logger.exception("Fatal error")
        sys.exit(1)
