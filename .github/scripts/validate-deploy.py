#!/usr/bin/env python3
"""Validate deployed website for GitHub Pages compatibility."""

import os
import sys
import json
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Optional
from dataclasses import dataclass

# Auto-install dependencies
try:
    from bs4 import BeautifulSoup
    from rich.console import Console
    from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn
    from rich.panel import Panel
    from rich.table import Table
    from rich.tree import Tree
    from loguru import logger
    from pydantic import BaseModel, Field
except ImportError:
    print("📦 Installing dependencies...")
    import subprocess
    subprocess.check_call([
        sys.executable, "-m", "pip", "install",
        "beautifulsoup4", "lxml", "rich", "loguru", "pydantic", "-q"
    ])
    from bs4 import BeautifulSoup
    from rich.console import Console
    from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn
    from rich.panel import Panel
    from rich.table import Table
    from rich.tree import Tree
    from loguru import logger
    from pydantic import BaseModel, Field

# Setup console and logger
console = Console()
logger.remove()
logger.add(
    "/tmp/validate-deploy-{time}.log",
    format="{time:YYYY-MM-DD HH:mm:ss} | {level: <8} | {message}",
    level="DEBUG"
)
logger.add(lambda msg: None)


class PathIssue(BaseModel):
    """Path issue data model (pydantic validation)."""
    file: str = Field(..., description="File path")
    bad_hrefs: List[str] = Field(default_factory=list, max_items=10)
    bad_srcs: List[str] = Field(default_factory=list, max_items=10)


@dataclass
class FileStats:
    """File statistics."""
    total: int = 0
    html: int = 0
    css: int = 0
    js: int = 0
    images: int = 0


class DeploymentValidator:
    """Validate deployment for GitHub Pages."""
    
    def __init__(self, strict_mode: bool = False, base_href: str = "/"):
        self.strict_mode = strict_mode
        self.base_href = base_href
        self.error_count = 0
        self.warning_count = 0
        self.cwd = Path.cwd()
        
        logger.info(f"Validator initialized: strict={strict_mode}, base_href={base_href}")
    
    def count_files(self) -> FileStats:
        """Count files by type."""
        all_files = [
            f for f in self.cwd.rglob("*")
            if f.is_file() and ".git" not in f.parts and ".github" not in f.parts
        ]
        
        stats = FileStats(
            total=len(all_files),
            html=len([f for f in all_files if f.suffix == '.html']),
            css=len([f for f in all_files if f.suffix == '.css']),
            js=len([f for f in all_files if f.suffix == '.js']),
            images=len([f for f in all_files if f.suffix in ['.png', '.jpg', '.jpeg', '.gif', '.svg', '.webp']])
        )
        
        logger.debug(f"File stats: {stats}")
        return stats
    
    def validate_index_html(self) -> bool:
        """Validate index.html exists and is valid."""
        index_path = self.cwd / "index.html"
        
        if not index_path.exists():
            console.print("[red]❌ index.html not found[/red]")
            self.error_count += 1
            logger.error("index.html missing")
            return False
        
        size = index_path.stat().st_size
        
        if size < 100:
            console.print(f"[red]❌ index.html too small: {size} bytes[/red]")
            self.error_count += 1
            logger.error(f"index.html too small: {size} bytes")
            return False
        
        console.print(f"[green]✅ index.html found ({size:,} bytes)[/green]")
        logger.info(f"index.html valid: {size} bytes")
        return True
    
    def validate_base_href(self) -> bool:
        """Validate base href for subpath deployments."""
        if self.base_href in ["/", ""]:
            return True
        
        index_path = self.cwd / "index.html"
        if not index_path.exists():
            return False
        
        content = index_path.read_text(encoding="utf-8", errors="ignore")
        soup = BeautifulSoup(content, "lxml")
        
        base_tag = soup.find("base", attrs={"href": True})
        
        if not base_tag:
            console.print(f"[yellow]⚠️  Missing <base href> for subpath: {self.base_href}[/yellow]")
            self.warning_count += 1
            logger.warning("Missing <base href> tag")
            return False
        
        found_href = base_tag["href"]
        expected = [self.base_href, self.base_href + "/"]
        
        if found_href in expected:
            console.print(f"[green]✅ Base href correct: {found_href}[/green]")
            logger.info(f"Base href valid: {found_href}")
            return True
        else:
            console.print(f"[yellow]⚠️  Base href mismatch: expected {self.base_href}, found {found_href}[/yellow]")
            self.warning_count += 1
            logger.warning(f"Base href mismatch: {found_href} != {self.base_href}")
            return False
    
    def validate_paths(self) -> List[PathIssue]:
        """Validate all HTML paths."""
        html_files = [
            f for f in self.cwd.rglob("*.html")
            if ".git" not in f.parts and ".github" not in f.parts
        ]
        
        if not html_files:
            console.print("[yellow]ℹ️  No HTML files to validate[/yellow]")
            return []
        
        issues: List[PathIssue] = []
        
        with Progress(
            SpinnerColumn(),
            TextColumn("[cyan]Scanning HTML files..."),
            BarColumn(),
            console=console
        ) as progress:
            task = progress.add_task("", total=len(html_files))
            
            for html_file in html_files:
                try:
                    content = html_file.read_text(encoding="utf-8", errors="ignore")
                    soup = BeautifulSoup(content, "lxml")  # Fast lxml!
                    
                    bad_hrefs = []
                    bad_srcs = []
                    
                    # Check href
                    for tag in soup.find_all(attrs={"href": True}):
                        href = tag["href"]
                        if href.startswith("/") and not href.startswith("//"):
                            bad_hrefs.append(href)
                    
                    # Check src
                    for tag in soup.find_all(attrs={"src": True}):
                        src = tag["src"]
                        if src.startswith("/") and not src.startswith(("/", "data:")):
                            bad_srcs.append(src)
                    
                    if bad_hrefs or bad_srcs:
                        issue = PathIssue(
                            file=str(html_file.relative_to(self.cwd)),
                            bad_hrefs=bad_hrefs[:10],
                            bad_srcs=bad_srcs[:10]
                        )
                        issues.append(issue)
                        logger.warning(f"Path issues in {html_file.name}: {len(bad_hrefs)} hrefs, {len(bad_srcs)} srcs")
                
                except Exception as e:
                    logger.error(f"Error parsing {html_file.name}: {e}")
                
                progress.update(task, advance=1)
        
        if issues:
            if self.strict_mode:
                self.error_count += 1
            else:
                self.warning_count += 1
        
        return issues
    
    def show_issues(self, issues: List[PathIssue]):
        """Display path issues with rich formatting."""
        if not issues:
            console.print("\n[green]✅ All paths are relative or external[/green]")
            return
        
        console.print(f"\n[yellow]⚠️  Found {len(issues)} file(s) with root-relative paths:[/yellow]\n")
        
        for issue in issues[:5]:  # Show first 5
            panel_content = []
            
            if issue.bad_hrefs:
                panel_content.append(f"[red]🔗 {len(issue.bad_hrefs)} href issues:[/red]")
                for href in issue.bad_hrefs[:3]:
                    panel_content.append(f"  • {href}")
                if len(issue.bad_hrefs) > 3:
                    panel_content.append(f"  ... +{len(issue.bad_hrefs) - 3} more")
            
            if issue.bad_srcs:
                panel_content.append(f"[red]🖼️  {len(issue.bad_srcs)} src issues:[/red]")
                for src in issue.bad_srcs[:3]:
                    panel_content.append(f"  • {src}")
                if len(issue.bad_srcs) > 3:
                    panel_content.append(f"  ... +{len(issue.bad_srcs) - 3} more")
            
            console.print(Panel(
                "\n".join(panel_content),
                title=f"📄 {issue.file}",
                border_style="yellow"
            ))
        
        if len(issues) > 5:
            console.print(f"\n[yellow]... and {len(issues) - 5} more files with issues[/yellow]")
        
        # Save detailed JSON report
        report_file = Path("/tmp/path-issues-detail.json")
        report_file.write_text(json.dumps([issue.dict() for issue in issues], indent=2))
        console.print(f"\n[blue]📊 Detailed report: {report_file}[/blue]")
    
    def run(self) -> int:
        """Run validation with rich UI."""
        # Header
        console.print(Panel.fit(
            "[bold green]🔍 Deployment Validator[/bold green]\n"
            f"[yellow]Mode:[/yellow] {'STRICT' if self.strict_mode else 'SOFT'}\n"
            f"[yellow]Base:[/yellow] {self.base_href or '/'}\n"
            "[cyan]Using:[/cyan] BeautifulSoup + lxml + pydantic",
            border_style="green"
        ))
        
        logger.info(f"Validation started: {datetime.now()}")
        
        # File statistics
        console.print("\n[bold cyan]📊 File Statistics[/bold cyan]")
        stats = self.count_files()
        
        stats_table = Table(show_header=False, border_style="cyan")
        stats_table.add_column("Metric", style="cyan")
        stats_table.add_column("Count", style="magenta")
        stats_table.add_row("📁 Total", str(stats.total))
        stats_table.add_row("📜 HTML", str(stats.html))
        stats_table.add_row("🎨 CSS", str(stats.css))
        stats_table.add_row("⚡ JS", str(stats.js))
        stats_table.add_row("🖼️  Images", str(stats.images))
        console.print(stats_table)
        
        # Validations
        console.print("\n[bold cyan]🔍 Running Validations[/bold cyan]\n")
        
        self.validate_index_html()
        if self.base_href not in ["/", ""]:
            self.validate_base_href()
        
        issues = self.validate_paths()
        self.show_issues(issues)
        
        # Summary
        console.print("\n" + "━" * 60)
        
        if self.error_count > 0:
            console.print(f"\n[bold red]❌ VALIDATION FAILED[/bold red]")
            console.print(f"[red]Errors: {self.error_count}[/red]")
            console.print(f"[yellow]Warnings: {self.warning_count}[/yellow]")
        elif self.warning_count > 0:
            console.print(f"\n[bold yellow]⚠️  PASSED WITH WARNINGS[/bold yellow]")
            console.print(f"[yellow]Warnings: {self.warning_count}[/yellow]")
        else:
            console.print(f"\n[bold green]✅ VALIDATION PASSED[/bold green]")
            console.print("[green]No errors or warnings[/green]")
        
        console.print(f"\n[blue]📝 Log saved to /tmp/validate-deploy-*.log[/blue]")
        
        logger.info(f"Validation complete: {self.error_count} errors, {self.warning_count} warnings")
        return 1 if self.error_count > 0 else 0


if __name__ == "__main__":
    strict_mode = os.environ.get("STRICT_VALIDATION", "false").lower() == "true"
    base_href = os.environ.get("BASE_HREF", "/")
    
    try:
        validator = DeploymentValidator(strict_mode=strict_mode, base_href=base_href)
        sys.exit(validator.run())
    except KeyboardInterrupt:
        console.print("\n[red]⚠️  Interrupted by user[/red]")
        sys.exit(1)
    except Exception as e:
        console.print(f"\n[red]❌ Fatal error: {e}[/red]")
        logger.exception("Fatal error")
        sys.exit(1)
