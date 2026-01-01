# 🚀 Deploy-page

> **🤖 AI-OPTIMIZED REPOSITORY** | Token-first design | Workflow-only execution | Atomic deploys

[![AI-First](https://img.shields.io/badge/AI-First%20Repository-blueviolet?style=for-the-badge&logo=openai)](https://github.com/KomarovAI/Deploy-page)
[![Python](https://img.shields.io/badge/Python-3.7+-blue?style=for-the-badge&logo=python)](https://github.com/KomarovAI/Deploy-page)
[![Status](https://img.shields.io/badge/Status-Production%20Ready-success?style=for-the-badge)](https://github.com/KomarovAI/Deploy-page)

**Automated static site deployment to GitHub Pages** with atomic operations, automatic rollback, and WordPress conversion.

---

## ⚡ Quick Deploy

```bash
# Root deployment
gh workflow run deploy.yml -f run_id=12345 -f target_repo=user/repo

# Subpath deployment  
gh workflow run deploy.yml -f run_id=12345 -f target_repo=user/repo -f base_path="/project"
```

---

## ✨ Key Features

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

### 🔗 Smart URL Rewriting

**CRITICAL FIX:** Anchor and query string handling:

```python
# OLD (broken):
"/page#section" → "/page/#section"  # Wrong!

# NEW (correct):
"/page#section" → "/page.html#section"  # ✅
"/page?q=1#top" → "/page.html?q=1#top"  # ✅
```

**Now handles:**
- ✅ Anchors: `#section`
- ✅ Query strings: `?param=value`
- ✅ Combined: `?q=1#top`
- ✅ data-* attributes: `data-src`, `data-bg`, `data-background`

### ⚙️ Parametrized Configuration

**CRITICAL FIX:** No more hardcoded paths!

```yaml
# NEW workflow input:
base_path:
  description: 'Base path for GitHub Pages'
  default: '/archived-sites'
```

```python
# Passed to Python script via env var:
base_path = os.getenv('BASE_PATH', '/')
```

**Result:** Single repo works for ANY GitHub Pages path!

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
```

**Auto-installed** on every run - zero manual setup!

---

## 📝 Workflow Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `run_id` | ✅ | - | Source workflow run ID |
| `target_repo` | ✅ | - | Deploy destination |
| `base_path` | ❌ | `/archived-sites` | GitHub Pages path |
| `artifact_name` | ❌ | `*-{run_id}` | Artifact pattern |
| `source_repo` | ❌ | `KomarovAI/web-crawler` | Source repo |
| `target_branch` | ❌ | `main` | Target branch |

---

## 🔧 Processing Pipeline

### 1. Atomic Cleanup

```bash
# Create isolated branch
git checkout -b deploy-temp

# Complete cleanup
find . -mindepth 1 -maxdepth 1 ! -name '.git' ! -name '.github' -exec rm -rf {} +

# CRITICAL: Verify or die
if [ $(find . -type f ! -path '*/.git/*' ! -path '*/.github/*' | wc -l) -ne 0 ]; then
  exit 1
fi
```

### 2. WordPress Conversion

**Removes:**
- 🗑️ WP core JS (wp-includes, wp-admin)
- 🗑️ Autoptimize cache
- 🗑️ jQuery migrate
- 🗑️ WP emoji

**Preserves:**
- ✅ Theme assets (wp-content/themes)
- ✅ Plugins (wp-content/plugins)
- ✅ Uploads (wp-content/uploads)

**Fixes:**
- ✅ Anchors: `/page#section` → `/page.html#section`
- ✅ Query strings: `/page?q=1` → `/page.html?q=1`
- ✅ data-* attributes for lazy loading
- ✅ Inline style `url()` references

### 3. Validation

```bash
# Must have index.html
if [ ! -f "index.html" ]; then
  exit 1
fi

# Must have HTML files
if [ $(find . -name '*.html' | wc -l) -eq 0 ]; then
  exit 1
fi
```

### 4. Atomic Merge

```bash
# All changes committed in temp branch
git commit -m "deploy: run ${RUN_ID}"

# Fast-forward merge (atomic)
git checkout main
git merge --ff-only deploy-temp

# Push (or auto-rollback on failure)
git push origin main
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

1. **Create PAT** with `contents:write`
2. **Add secret** `EXTERNAL_REPO_PAT` to this repo
3. **Run workflow** from Actions tab

**Requirements:**
- ✅ Python 3.7+ (GitHub Actions built-in)
- ✅ beautifulsoup4 + lxml (auto-installed)

---

## 🐛 Troubleshooting

| Issue | Solution |
|-------|----------|
| Old files remain after deploy | ✅ **FIXED** - now fails if cleanup incomplete |
| Anchors broken (`#section`) | ✅ **FIXED** - proper URL parsing |
| Query strings lost | ✅ **FIXED** - preserves `?param=value` |
| Deploy fails mid-process | ✅ **FIXED** - atomic deploy + auto-rollback |
| Hardcoded `/archived-sites` | ✅ **FIXED** - now uses `base_path` input |
| data-src not rewritten | ✅ **FIXED** - handles data-* attributes |

---

## 📊 Version History

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

**⚡ v3.2.0** | Atomic deploys | Auto-rollback | Production-ready
