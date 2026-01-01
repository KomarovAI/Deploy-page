#!/usr/bin/env python3
"""Fix static site issues for GitHub Pages deployment."""

import sys
from pathlib import Path
from typing import List, Tuple

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
    
    # Navigation fix JavaScript
    NAVIGATION_FIX_JS = '''<script>
// Override WordPress navigation for GitHub Pages
(function() {
  'use strict';
  
  // Intercept all link clicks
  document.addEventListener('click', function(e) {
    const link = e.target.closest('a');
    if (!link) return;
    
    const href = link.getAttribute('href');
    if (!href) return;
    
    // Skip external links, anchors, and special protocols
    if (href.startsWith('http://') || 
        href.startsWith('https://') || 
        href.startsWith('//') ||
        href.startsWith('#') ||
        href.startsWith('mailto:') ||
        href.startsWith('tel:')) {
      return;
    }
    
    // For internal links, ensure .html extension
    e.preventDefault();
    
    let fixedHref = href;
    
    // Remove leading slash if present
    if (fixedHref.startsWith('/')) {
      fixedHref = '.' + fixedHref;
    }
    
    // Add .html if no extension present
    const hasExtension = /\.[a-z0-9]+$/i.test(fixedHref.split('?')[0].split('#')[0]);
    if (!hasExtension) {
      const parts = fixedHref.split('#');
      parts[0] = parts[0].split('?')[0] + '.html' + (fixedHref.includes('?') ? '?' + fixedHref.split('?')[1].split('#')[0] : '');
      fixedHref = parts.join('#');
    }
    
    // Navigate
    window.location.href = fixedHref;
  }, false);
  
  console.log('\u2705 GitHub Pages navigation fix active');
})();
</script>'''
    
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
        logger.info("StaticSiteFixer initialized")
    
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
        
        # Create script tag
        script_tag = soup.new_tag('script')
        script_tag.string = self.NAVIGATION_FIX_JS.strip()
        
        # Insert before </body>
        body.append(script_tag)
        logger.debug("Navigation fix injected")
        return True
    
    def process_html_file(self, file_path: Path) -> Tuple[bool, int]:
        """Process a single HTML file."""
        try:
            content = file_path.read_text(encoding="utf-8", errors="ignore")
            soup = BeautifulSoup(content, "lxml")  # Fast lxml parser!
            
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
            "[bold magenta]🚀 Static Site Fixer[/bold magenta]\n"
            "[yellow]Fixing:[/yellow] WordPress static exports\n"
            "[green]Actions:[/green] Inject navigation fix, remove legacy scripts",
            border_style="magenta"
        ))
        
        cwd = Path.cwd()
        logger.info(f"Working directory: {cwd}")
        
        # Find HTML files
        html_files = [
            f for f in cwd.rglob("*.html")
            if ".git" not in f.parts and ".github" not in f.parts
        ]
        
        if not html_files:
            console.print("[yellow]⚠️  No HTML files found[/yellow]")
            return 0
        
        console.print(f"\n[cyan]Found {len(html_files)} HTML files[/cyan]\n")
        
        # Process with progress bar
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            BarColumn(),
            TaskProgressColumn(),
            console=console
        ) as progress:
            
            task = progress.add_task(
                "[magenta]Processing HTML files...",
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
        
        table.add_row("HTML files scanned", str(len(html_files)))
        table.add_row("Files modified", f"[bold]{self.files_processed}[/bold]")
        table.add_row("Navigation fixes injected", f"[bold]{self.js_injected}[/bold]")
        table.add_row("Legacy scripts removed", f"[bold]{self.scripts_removed}[/bold]")
        
        console.print(table)
        
        if self.files_processed == 0:
            console.print("\n[yellow]ℹ️  No modifications needed[/yellow]")
        else:
            console.print(f"\n[green]✨ Successfully fixed {self.files_processed} file(s)![/green]")
        
        logger.info(f"Processing complete: {self.files_processed} files modified")
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
