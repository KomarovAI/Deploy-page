# 🚀 Deploy-page

> **🤖 AI-OPTIMIZED REPOSITORY** | Token-first design | Workflow-only execution | Atomic deploys

[![AI-First](https://img.shields.io/badge/AI-First%20Repository-blueviolet?style=for-the-badge&logo=openai)](https://github.com/KomarovAI/Deploy-page)
[![Python](https://img.shields.io/badge/Python-3.7+-blue?style=for-the-badge&logo=python)](https://github.com/KomarovAI/Deploy-page)
[![Status](https://img.shields.io/badge/Status-Production%20Ready-success?style=for-the-badge)](https://github.com/KomarovAI/Deploy-page)

**Complete website archiving and deployment solution** with CSS/JS preservation, atomic operations, automatic rollback, and WordPress conversion.

---

## 🎯 Two-Mode Operation

### Mode 1: 📦 Website Archiving (NEW!)

**Complete site mirror with all resources:**

```bash
# Via GitHub Actions (recommended)
gh workflow run archive-site.yml \
  -f url="https://example.com" \
  -f depth=2 \
  -f branch="archived-sites"

# Or locally
python scripts/archive_site.py https://example.com --depth 2
```

**What's preserved:**
- ✅ **HTML** structure
- ✅ **CSS** files (external + inline)
- ✅ **JavaScript** files
- ✅ **Images** (all formats)
- ✅ **Fonts** (woff, ttf, etc.)
- ✅ **All linked assets**

**Auto-fixes:**
- 🔧 Relative paths in HTML
- 🔧 `url()` references in CSS
- 🔧 Directory structure preservation
- 🔧 Query string handling

[📖 Full archiving documentation](docs/ARCHIVING.md)

### Mode 2: 🚀 Deployment

**Deploy pre-crawled content to GitHub Pages:**

```bash
# Root deployment
gh workflow run deploy.yml -f run_id=12345 -f target_repo=user/repo

# Subpath deployment  
gh workflow run deploy.yml -f run_id=12345 -f target_repo=user/repo -f base_path="/project"

# Convert absolute URLs
gh workflow run deploy.yml -f run_id=12345 -f target_repo=user/repo \
  -f base_path="/archived-sites" \
  -f original_domain="https://www.example.com"
```

---

## ⚡ Quick Start

### Archive a Website

**Option A: GitHub Actions (No setup required)**

1. Go to **Actions** → **Archive Website**
2. Click **Run workflow**
3. Enter URL and depth
4. ✅ Done! Check `archived-sites` branch

**Option B: Local Execution**

```bash
# Clone repository
git clone https://github.com/KomarovAI/Deploy-page
cd Deploy-page

# Install dependencies
pip install -r scripts/requirements.txt

# Archive website
python scripts/archive_site.py https://example.com \
  --output ./archived_sites \
  --depth 2

# View archived site
cd archived_sites/example.com
python -m http.server 8000
# Open http://localhost:8000
```

### Deploy Archived Site

```bash
# After archiving, deploy to GitHub Pages
gh workflow run deploy.yml \
  -f run_id=YOUR_RUN_ID \
  -f target_repo=username/github-pages-repo \
  -f base_path="/archived-sites"
```

---

## ✨ Key Features

### 📦 Complete Website Archiving (v4.0.0)

**NEW:** Full-featured site archiver that preserves ALL resources!

**Features:**
- ✅ **Downloads everything**: CSS, JS, images, fonts, media
- ✅ **Recursive crawling**: Follow links within same domain
- ✅ **Path fixing**: Auto-converts absolute to relative paths
- ✅ **CSS processing**: Fixes `url()` references in stylesheets
- ✅ **Smart caching**: Avoids duplicate downloads
- ✅ **Metadata tracking**: JSON file with archive statistics

**Why it solves the CSS problem:**

```python
# Before (broken):
# HTML only, no CSS, empty styles
<link rel="stylesheet" href="https://example.com/style.css"> <!-- 404 -->

# After (working):
# CSS downloaded and paths fixed
<link rel="stylesheet" href="./style.css"> <!-- ✅ Local file -->
```

**Architecture:**

```python
class SiteArchiver:
    def process_html(url):
        # 1. Download HTML
        soup = BeautifulSoup(html)
        
        # 2. Download CSS
        for link in soup.find_all('link', rel='stylesheet'):
            css_url = urljoin(url, link['href'])
            local_path = download_resource(css_url)
            link['href'] = local_path  # Fix path
        
        # 3. Fix CSS url() references
        css_content = fix_css_paths(css_content, css_url)
        
        # 4. Download JS, images, fonts...
        # 5. Save with proper structure
```

**Output structure:**

```
archived_sites/
└── example.com/
    ├── index.html              # Main page
    ├── about.html              # Linked pages
    ├── style.css               # ✅ Downloaded CSS
    ├── script.js               # ✅ Downloaded JS
    ├── images/
    │   ├── logo.png            # ✅ All images
    │   └── banner.jpg
    ├── fonts/
    │   └── font.woff2          # ✅ All fonts
    └── archive_metadata.json   # Statistics
```

### 🔒 Atomic Deployments (v3.2.0)

**Problem:** Traditional deploys can leave repos in broken state if something fails mid-process.

**Solution:** Deploy via temporary branch + fast-forward merge:

```yaml
1. Create deploy-temp branch
2. Clean + copy + convert in isolation
3. Validate everything
4. Merge to main (atomic)
5. Auto-rollback on ANY failure
```

**Guarantees:**
- ✅ All-or-nothing deployment
- ✅ Zero downtime
- ✅ Automatic rollback to last known-good state
- ✅ Never leaves repo in broken state

### 🧹 Complete Repository Cleanup

**CRITICAL FIX:** Now uses proper cleanup with verification:

```bash
# Remove everything except .git and .github
find . -mindepth 1 -maxdepth 1 ! -name '.git' ! -name '.github' -exec rm -rf {} +

# VERIFY cleanup (hard fail if files remain)
REMAINING=$(find . -type f ! -path '*/.git/*' ! -path '*/.github/*' | wc -l)
if [ $REMAINING -ne 0 ]; then
  echo "❌ FATAL: $REMAINING files remain!"
  exit 1  # Aborts deploy
fi
```

**Before:** Warning only + might leak old files  
**After:** Hard failure + guaranteed clean slate

### 🔗 Smart URL Rewriting (v3.3.0)

**NEW:** Automatic conversion of absolute URLs from original domain!

```python
# Input site:
<a href="https://www.example.com/page">Link</a>
<img src="https://www.example.com/image.jpg">

# After conversion (with base_path="/archived-sites"):
<a href="/archived-sites/page.html">Link</a>
<img src="/archived-sites/image.jpg">
```

**Features:**
- ✅ Converts absolute URLs: `https://domain.com/path` → `/base-path/path`
- ✅ Preserves external links (different domains)
- ✅ Handles protocol-relative URLs: `//domain.com/path`
- ✅ Anchors: `#section`
- ✅ Query strings: `?param=value`
- ✅ Combined: `?q=1#top`
- ✅ data-* attributes: `data-src`, `data-bg`, `data-background`

### ⚙️ Parametrized Configuration

**CRITICAL FIX:** No more hardcoded paths!

```yaml
# NEW workflow inputs:
base_path:
  description: 'Base path for GitHub Pages'
  default: '/archived-sites'
original_domain:
  description: 'Original domain to convert'
  default: ''  # e.g. https://example.com
```

```python
# Passed to Python script via env vars:
base_path = os.getenv('BASE_PATH', '/')
original_domain = os.getenv('ORIGINAL_DOMAIN', '')
```

**Result:** Single repo works for ANY GitHub Pages path AND domain!

---

## 🐍 Python-Only Architecture

### Why Python?

| Bash/sed/awk | Python + BeautifulSoup | Result |
|--------------|------------------------|--------|
| ❌ Regex hell | ✅ DOM manipulation | **Reliable** |
| ❌ Edge cases | ✅ Handles all HTML | **Safe** |
| ❌ Fragile | ✅ Industry standard | **Production-ready** |

### Libraries

```python
from bs4 import BeautifulSoup  # 11.3K ⭐ - HTML parsing
from lxml import etree         # 3x faster parser
import requests                # HTTP client
```

**Auto-installed** on every run - zero manual setup!

---

## 📝 Workflow Inputs

### Archive Website Workflow

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `url` | ✅ | - | Website URL to archive |
| `depth` | ❌ | `2` | Crawl depth (0-3) |
| `branch` | ❌ | `archived-sites` | Target branch |

### Deploy Workflow

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `run_id` | ✅ | - | Source workflow run ID |
| `target_repo` | ✅ | - | Deploy destination |
| `base_path` | ❌ | `/archived-sites` | GitHub Pages path |
| `original_domain` | ❌ | `` | Original site domain (e.g. `https://example.com`) |
| `artifact_name` | ❌ | `*-{run_id}` | Artifact pattern |
| `source_repo` | ❌ | `KomarovAI/web-crawler` | Source repo |
| `target_branch` | ❌ | `main` | Target branch |

---

## 🔧 Processing Pipeline

### Mode 1: Archiving

```python
1. Download HTML from URL
2. Parse with BeautifulSoup
3. Extract all resource links:
   - CSS (link[rel=stylesheet])
   - JS (script[src])
   - Images (img[src])
   - Fonts (from CSS @font-face)
4. Download each resource
5. Fix paths:
   - HTML: href/src attributes
   - CSS: url() references
6. Save with directory structure
7. Create metadata.json
```

### Mode 2: Deployment

```bash
1. Atomic Cleanup
2. WordPress Conversion
3. Validation
4. Atomic Merge
```

---

## 🛑 Automatic Rollback

**NEW:** Rollback happens automatically on ANY failure:

```yaml
- name: Rollback on failure
  if: failure()
  run: |
    git reset --hard ${{ steps.snapshot.outputs.snapshot_sha }}
    git push origin main --force
```

**Triggers on:**
- ❌ Cleanup verification fails
- ❌ File copy fails
- ❌ WordPress conversion fails
- ❌ Validation fails
- ❌ Push fails

**Result:** Repository ALWAYS stays in working state!

---

## 🛠️ Setup

### For Archiving

**GitHub Actions:**
- ✅ No setup needed!
- Just click "Run workflow"

**Local:**
```bash
pip install -r scripts/requirements.txt
```

### For Deployment

1. **Create PAT** with `contents:write`
2. **Add secret** `EXTERNAL_REPO_PAT` to this repo
3. **Run workflow** from Actions tab

**Requirements:**
- ✅ Python 3.7+ (GitHub Actions built-in)
- ✅ beautifulsoup4 + lxml + requests (auto-installed)

---

## 🐛 Troubleshooting

### Archiving Issues

| Issue | Solution |
|-------|----------|
| **Missing CSS** | ✅ **FIXED** - script downloads all CSS automatically |
| Broken images | Check if images loaded via JavaScript (not supported) |
| Slow archiving | Reduce depth or archive specific pages only |
| Permission errors | Some sites block bots, respect robots.txt |

### Deployment Issues

| Issue | Solution |
|-------|----------|
| Old files remain after deploy | ✅ **FIXED** - now fails if cleanup incomplete |
| Anchors broken (`#section`) | ✅ **FIXED** - proper URL parsing |
| Query strings lost | ✅ **FIXED** - preserves `?param=value` |
| Deploy fails mid-process | ✅ **FIXED** - atomic deploy + auto-rollback |
| Hardcoded `/archived-sites` | ✅ **FIXED** - now uses `base_path` input |
| data-src not rewritten | ✅ **FIXED** - handles data-* attributes |
| **Absolute URLs broken** | ✅ **FIXED** - set `original_domain` parameter |

---

## 📚 Documentation

- [ARCHIVING.md](docs/ARCHIVING.md) - Complete archiving guide
- [DEPLOY.md](DEPLOY.md) - Deployment guide
- [CHANGELOG.md](CHANGELOG.md) - Version history

---

## 📊 Version History

### v4.0.0 (2026-01-02) — Complete Site Archiver 📦

**Added:**
- ✨ **Full website archiving** with CSS/JS/assets
- ✨ `archive-site.yml` workflow for automated archiving
- ✨ `archive_site.py` script with recursive crawling
- ✨ CSS `url()` path fixing
- ✨ Metadata generation (JSON statistics)
- ✨ Resource deduplication (smart caching)
- ✨ Configurable crawl depth (0-3)
- ✨ Rate limiting (0.5s delay)

**Documentation:**
- 📖 Added `docs/ARCHIVING.md` with full guide
- 📖 Updated README with archiving section

**Why this matters:**
- 🎯 Solves the "CSS missing" problem completely
- 🎯 Preserves ALL website resources
- 🎯 Works offline (no external dependencies)
- 🎯 GitHub Actions integration

### v3.3.0 (2026-01-01) — Absolute URL Conversion 🔗

**Added:**
- ✨ `original_domain` workflow input
- ✨ Automatic absolute URL conversion: `https://domain.com/path` → `/base-path/path`
- ✨ Protocol-relative URL support: `//domain.com/path`
- ✨ External link preservation (different domains)
- ✨ Conversion counter in logs: `🔗 Converted N absolute URLs`

**Fixed:**
- ✅ Links to original domain now work in GitHub Pages
- ✅ Mixed absolute/relative URLs handled correctly

### v3.2.0 (2026-01-01) — Atomic Deploy + Critical Fixes 🔥

**Breaking:**
- 🔒 Atomic deployments via temp branch
- 🛑 Automatic rollback on failure
- ⚠️ Hard fail on incomplete cleanup (was: warning only)

**Fixed:**
- ✅ Anchor bug: `/page#section` now works correctly
- ✅ Query string preservation: `/page?q=1#top`
- ✅ Hardcoded `BASE_PATH` now parametrized via workflow input
- ✅ data-* attributes (data-src, data-bg) now rewritten
- ✅ Cleanup verification now FATAL (was: warning)

**Added:**
- ✨ `base_path` workflow input (customizable GitHub Pages path)
- ✨ Atomic merge via `--ff-only`
- ✨ Rollback step triggered on `if: failure()`

### v3.1.0 (2026-01-01) — Premium Libraries

- ✨ BeautifulSoup + lxml (3x faster)
- ✨ Auto-install dependencies

### v3.0.0 (2026-01-01) — Python Rewrite

- 🔥 Replaced bash/sed with Python
- 🔥 BeautifulSoup DOM manipulation

---

## 🔗 Ecosystem

- [web-crawler](https://github.com/KomarovAI/web-crawler) - Generates site artifacts
- [ai-content-auto-generator](https://github.com/KomarovAI/ai-content-auto-generator) - AI content

## 📝 License

MIT

---

**⚡ v4.0.0** | Complete archiving | CSS/JS preservation | Atomic deploys | Production-ready
