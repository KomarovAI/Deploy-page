#!/usr/bin/env python3
"""Fix paths for GitHub Pages deployment."""

import os
import sys
import re
from pathlib import Path
from urllib.parse import urlparse, urlunparse
from typing import Optional, List, Tuple

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
logger.remove()  # Remove default handler
logger.add(
    "/tmp/fix-paths-{time}.log",
    format="{time:YYYY-MM-DD HH:mm:ss} | {level: <8} | {message}",
    level="DEBUG"
)
logger.add(lambda msg: None)  # Suppress console output from loguru


class PathFixer:
    """Fix paths for GitHub Pages compatibility."""
    
    def __init__(self, base_href: str = "/"):
        self.base_href = base_href.rstrip("/")
        self.files_modified = 0
        self.total_changes = 0
        logger.info(f"PathFixer initialized with base_href={base_href}")
        
    def should_add_html_extension(self, path: str) -> bool:
        """Check if path needs .html extension."""
        filename = path.split('/')[-1].split('?')[0].split('#')[0]
        if '.' in filename:
            return False
        
        if not path or path.startswith(('http://', 'https://', '//', '#')):
            return False
        
        return True
    
    def fix_url(self, url: str, attr_type: str = "href") -> str:
        """Fix a single URL."""
        original_url = url
        parsed = urlparse(url)
        
        # Fix domain-absolute URLs
        if 'www.caterkitservices.com' in url:
            url = url.replace('https://www.caterkitservices.com/', './')
            url = url.replace('http://www.caterkitservices.com/', './')
            parsed = urlparse(url)
            logger.debug(f"Fixed domain URL: {original_url} → {url}")
        
        # Fix root-relative paths
        if parsed.path.startswith('/') and not parsed.netloc:
            if self.base_href in ["", "/"]:
                path = './' + parsed.path.lstrip('/')
            else:
                path = self.base_href + parsed.path if not parsed.path.startswith(self.base_href + '/') else parsed.path
            
            url = urlunparse((
                parsed.scheme, parsed.netloc, path,
                parsed.params, parsed.query, parsed.fragment
            ))
            parsed = urlparse(url)
            logger.debug(f"Fixed root-relative: {original_url} → {url}")
        
        # Add .html extension
        if attr_type == "href" and self.should_add_html_extension(parsed.path):
            base_path = parsed.path.split('?', 1)[0].split('#', 1)[0]
            
            if not base_path.endswith('.html'):
                base_path += '.html'
                url = urlunparse((
                    parsed.scheme, parsed.netloc, base_path,
                    parsed.params, parsed.query, parsed.fragment
                ))
                logger.debug(f"Added .html: {original_url} → {url}")
        
        return url if url != original_url else original_url
    
    def fix_css_urls(self, css_content: str) -> str:
        """Fix url() in CSS."""
        def replace_url(match):
            url = match.group(1).strip('"\'')
            fixed_url = self.fix_url(url, attr_type="src")
            quote = '"' if '"' in match.group(0) else "'"
            return f"url({quote}{fixed_url}{quote})"
        
        pattern = r'url\(["\']?([^"\')]+)["\']?\)'
        return re.sub(pattern, replace_url, css_content)
    
    def process_html_file(self, file_path: Path) -> Tuple[int, bool]:
        """Process a single HTML file."""
        try:
            content = file_path.read_text(encoding="utf-8", errors="ignore")
            soup = BeautifulSoup(content, "lxml")  # lxml is FASTER!
            changes = 0
            
            # Fix href attributes
            for tag in soup.find_all(attrs={"href": True}):
                original = tag["href"]
                fixed = self.fix_url(original, attr_type="href")
                if fixed != original:
                    tag["href"] = fixed
                    changes += 1
            
            # Fix src attributes
            for tag in soup.find_all(attrs={"src": True}):
                original = tag["src"]
                fixed = self.fix_url(original, attr_type="src")
                if fixed != original:
                    tag["src"] = fixed
                    changes += 1
            
            # Fix CSS url() in <style> tags
            for style_tag in soup.find_all("style"):
                if style_tag.string:
                    original_css = style_tag.string
                    fixed_css = self.fix_css_urls(original_css)
                    if fixed_css != original_css:
                        style_tag.string.replace_with(fixed_css)
                        changes += 1
            
            # Fix inline style attributes
            for tag in soup.find_all(attrs={"style": True}):
                original_style = tag["style"]
                fixed_style = self.fix_css_urls(original_style)
                if fixed_style != original_style:
                    tag["style"] = fixed_style
                    changes += 1
            
            if changes > 0:
                file_path.write_text(str(soup), encoding="utf-8")
                self.files_modified += 1
                self.total_changes += changes
                logger.info(f"{file_path.name}: {changes} changes")
                return changes, True
            
            return 0, False
            
        except Exception as e:
            logger.error(f"{file_path.name}: {e}")
            return 0, False
    
    def process_css_file(self, file_path: Path) -> Tuple[int, bool]:
        """Process a single CSS file."""
        try:
            content = file_path.read_text(encoding="utf-8", errors="ignore")
            fixed_content = self.fix_css_urls(content)
            
            if fixed_content != content:
                file_path.write_text(fixed_content, encoding="utf-8")
                changes = content.count('url(')
                self.files_modified += 1
                self.total_changes += changes
                logger.info(f"{file_path.name}: {changes} url() fixed")
                return changes, True
            
            return 0, False
                
        except Exception as e:
            logger.error(f"{file_path.name}: {e}")
            return 0, False
    
    def run(self):
        """Execute path fixing with rich UI."""
        # Header
        console.print(Panel.fit(
            "[bold cyan]🔧 GitHub Pages Path Fixer[/bold cyan]\n"
            f"[yellow]BASE_HREF:[/yellow] {self.base_href or '/'}\n"
            "[green]Using:[/green] BeautifulSoup + lxml (fast!)",
            border_style="cyan"
        ))
        
        cwd = Path.cwd()
        logger.info(f"Working directory: {cwd}")
        
        # Find files
        html_files = [
            f for f in cwd.rglob("*.html")
            if ".git" not in f.parts and ".github" not in f.parts
        ]
        
        css_files = [
            f for f in cwd.rglob("*.css")
            if ".git" not in f.parts and ".github" not in f.parts
        ]
        
        if not html_files and not css_files:
            console.print("[yellow]⚠️  No HTML/CSS files found[/yellow]")
            return 0
        
        # Process with progress bars
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            BarColumn(),
            TaskProgressColumn(),
            console=console
        ) as progress:
            
            # Process HTML files
            if html_files:
                task = progress.add_task(
                    f"[cyan]Processing HTML files...",
                    total=len(html_files)
                )
                
                for html_file in html_files:
                    changes, modified = self.process_html_file(html_file)
                    progress.update(task, advance=1)
            
            # Process CSS files
            if css_files:
                task = progress.add_task(
                    f"[cyan]Processing CSS files...",
                    total=len(css_files)
                )
                
                for css_file in css_files:
                    changes, modified = self.process_css_file(css_file)
                    progress.update(task, advance=1)
        
        # Summary table
        table = Table(title="\n📊 Summary", border_style="green")
        table.add_column("Metric", style="cyan", no_wrap=True)
        table.add_column("Value", style="magenta")
        
        table.add_row("Total files scanned", str(len(html_files) + len(css_files)))
        table.add_row("HTML files", str(len(html_files)))
        table.add_row("CSS files", str(len(css_files)))
        table.add_row("Files modified", f"[bold]{self.files_modified}[/bold]")
        table.add_row("Total changes", f"[bold]{self.total_changes}[/bold]")
        
        console.print(table)
        
        if self.files_modified == 0:
            console.print("\n[yellow]ℹ️  All files were already correct[/yellow]")
        else:
            console.print(f"\n[green]✨ Successfully updated {self.files_modified} file(s)![/green]")
        
        logger.info(f"Processing complete: {self.files_modified} files modified, {self.total_changes} changes")
        return 0


if __name__ == "__main__":
    base_href = os.environ.get("BASE_HREF", "/")
    
    try:
        fixer = PathFixer(base_href=base_href)
        sys.exit(fixer.run())
    except KeyboardInterrupt:
        console.print("\n[red]⚠️  Interrupted by user[/red]")
        sys.exit(1)
    except Exception as e:
        console.print(f"\n[red]❌ Fatal error: {e}[/red]")
        logger.exception("Fatal error")
        sys.exit(1)
