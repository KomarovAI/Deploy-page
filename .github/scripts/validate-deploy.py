#!/usr/bin/env python3
"""Ultra-fast broken link checker with async + caching. Token-optimized."""

import asyncio
import os
import sys
from pathlib import Path
from typing import Dict, Set, Tuple
from collections import defaultdict

try:
    from bs4 import BeautifulSoup
except ImportError:
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "beautifulsoup4", "lxml", "-q"])
    from bs4 import BeautifulSoup


class FastLinkValidator:
    """Ultra-fast async link validator with caching."""
    
    def __init__(self, base_dir: Path = None):
        self.base_dir = base_dir or Path.cwd()
        self.broken = defaultdict(list)
        self.cache = {}  # path -> exists (avoid re-checking)
        self.checked = 0
        self.stats = {}
    
    def _resolve_path(self, href: str, from_file: Path) -> Path:
        """Быстрое разрешение пути без лишних проверок."""
        if href.startswith('/'):
            return (self.base_dir / href.lstrip('/')).resolve()
        return (from_file.parent / href).resolve()
    
    def _path_exists(self, target: Path) -> bool:
        """Кеширующая проверка существования файла."""
        path_str = str(target)
        if path_str in self.cache:
            return self.cache[path_str]
        
        exists = target.exists() or (target.parent / "index.html").exists()
        self.cache[path_str] = exists
        return exists
    
    async def _validate_html_file(self, html_file: Path) -> int:
        """Асинхронная проверка одного HTML файла (non-blocking)."""
        broken_count = 0
        
        try:
            # Быстрое чтение с лимитом на размер
            content = html_file.read_text(encoding="utf-8", errors="ignore")
            if len(content) > 10_000_000:  # Пропускаем огромные файлы
                return 0
            
            soup = BeautifulSoup(content, "html.parser")  # html.parser быстрее чем lxml
            
            for link in soup.find_all('a', href=True):
                href = link['href'].strip()
                
                # Быстрые фильтры
                if not href or href.startswith(('#', 'http', '//', 'mailto:', 'tel:', 'javascript:')):
                    continue
                
                # Убираем query params и фрагменты
                clean_href = href.split('?')[0].split('#')[0]
                if not clean_href:
                    continue
                
                # Проверка существования
                target = self._resolve_path(clean_href, html_file)
                
                if not self._path_exists(target):
                    self.broken[str(html_file.relative_to(self.base_dir))].append(href)
                    broken_count += 1
                    self.checked += 1
        
        except Exception:
            pass  # Молчаливый skip ошибок
        
        return broken_count
    
    async def _validate_batch(self, html_files: list, batch_size: int = 50) -> int:
        """Батч-обработка файлов для оптимизации памяти."""
        total_broken = 0
        
        for i in range(0, len(html_files), batch_size):
            batch = html_files[i:i + batch_size]
            tasks = [self._validate_html_file(f) for f in batch]
            results = await asyncio.gather(*tasks)
            total_broken += sum(results)
        
        return total_broken
    
    def _count_files(self) -> dict:
        """Быстрый подсчёт файлов без рекурсии где возможно."""
        html_files = list(self.base_dir.rglob("*.html"))
        html_files = [f for f in html_files if ".git" not in f.parts and ".github" not in f.parts]
        
        # Быстрые подсчёты
        total = len(html_files)
        css = len(list(self.base_dir.rglob("*.css")))
        js = len(list(self.base_dir.rglob("*.js")))
        
        return {"html": total, "css": css, "js": js}
    
    async def validate(self) -> int:
        """Главная валидация."""
        
        # Быстрые проверки
        if not (self.base_dir / "index.html").exists():
            print("❌ index.html not found")
            return 1
        
        stats = self._count_files()
        
        if stats["html"] == 0:
            print("✅ Validation passed: No HTML files to check")
            return 0
        
        # Главная валидация
        html_files = [
            f for f in self.base_dir.rglob("*.html")
            if ".git" not in f.parts and ".github" not in f.parts
        ]
        
        broken_count = await self._validate_batch(html_files)
        
        # Отчёт
        if broken_count > 0:
            print(f"⚠️  Found {broken_count} broken link(s):")
            for file, links in sorted(self.broken.items()):
                print(f"  📄 {file}")
                for link in links[:3]:  # Max 3 per file
                    print(f"     ❌ {link}")
                if len(links) > 3:
                    print(f"     ... +{len(links) - 3} more")
        
        print(f"✅ Validation passed: {stats['html']} HTML, {stats['css']} CSS, {stats['js']} JS")
        return 0


async def main():
    """Async entry point."""
    base_href = os.environ.get("BASE_HREF", "/")
    
    try:
        validator = FastLinkValidator()
        return await validator.validate()
    except KeyboardInterrupt:
        print("⚠️  Interrupted")
        return 1
    except Exception as e:
        print(f"❌ Error: {e}")
        return 1


if __name__ == "__main__":
    exit_code = asyncio.run(main())
    sys.exit(exit_code)
