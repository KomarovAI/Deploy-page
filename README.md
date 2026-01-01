# 🚀 Deploy-page

> **🤖 AI-OPTIMIZED REPOSITORY** | Token-first design | Workflow-only execution | Zero local dependencies

[![AI-First](https://img.shields.io/badge/AI-First%20Repository-blueviolet?style=for-the-badge&logo=openai)](https://github.com/KomarovAI/Deploy-page)
[![Token-Efficient](https://img.shields.io/badge/Token-Efficient-green?style=for-the-badge)](https://github.com/KomarovAI/Deploy-page)
[![Workflow-Only](https://img.shields.io/badge/Execution-Workflow%20Only-orange?style=for-the-badge&logo=github-actions)](https://github.com/KomarovAI/Deploy-page)
[![Status](https://img.shields.io/badge/Status-Production%20Ready-success?style=for-the-badge)](https://github.com/KomarovAI/Deploy-page)

**Automated static site deployment to GitHub Pages** through GitHub Actions workflow orchestration with artifact-based content delivery, intelligent path rewriting, and zero-downtime rollback mechanisms.

---

## ⚡ Quick Deploy

```bash
# Root deployment
gh workflow run deploy.yml -f run_id=12345 -f target_repo=user/repo

# Subpath deployment
gh workflow run deploy.yml -f run_id=12345 -f target_repo=user/repo -f base_href="/project/"

# Manual trigger from GitHub UI
# Actions → Deploy Website to GitHub Pages → Run workflow
```

## 🎯 Core Features

- **Artifact Orchestration** - Pull from any GitHub Actions run
- **Smart Path Rewriting** - Absolute → relative (GitHub Pages compatible)
- **Query String Preservation** - `href="/page?q=1"` → `href="./page.html?q=1"`
- **Anchor Preservation** - `href="/page#top"` → `href="./page.html#top"`
- **Python-Based Processing** - Robust regex handling for complex patterns
- **Idempotent Scripts** - Safe to run multiple times
- **Automatic Rollback** - Git snapshot restoration on failure
- **Soft/Strict Validation** - Choose between warnings or hard failures
- **Detailed Logging** - Per-file issue tracking with JSON exports
- **Subpath Support** - Deploy to `/project/` paths
- **Zero Config** - No local setup required

## 📋 Workflow Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `run_id` | ✅ | - | Source workflow run ID |
| `target_repo` | ✅ | - | Deploy destination (owner/repo) |
| `artifact_name` | ❌ | `*-{run_id}` | Artifact name pattern |
| `source_repo` | ❌ | `KomarovAI/web-crawler` | Artifact source repo |
| `target_branch` | ❌ | `main` | Target branch |
| `base_href` | ❌ | `/` | Base path (`/` or `/project/`) |

## 🔧 Path Rewriting Logic

**fix-paths.sh** transforms URLs for GitHub Pages compatibility:

```html
<!-- Before -->
<link href="/styles.css">
<a href="/about?tab=team#intro">About</a>
<script src="https://example.com/app.js">

<!-- After (root deployment) -->
<link href="./styles.css">
<a href="./about.html?tab=team#intro">About</a>
<script src="./app.js">

<!-- After (subpath /project/) -->
<link href="/project/styles.css">
<a href="/project/about.html?tab=team#intro">About</a>
<script src="/project/app.js">
```

**Technology:**
- ✨ **Python-based** .html insertion (v2.7.1+) - robust regex handling
- ✅ Bash for simple replacements (domain URLs, root paths)
- ✅ No complex sed escaping issues

**Key Features:**
- ✅ Preserves query strings: `page?query=value`
- ✅ Preserves anchors: `page#section`
- ✅ Adds `.html` before queries: `page?q=1` → `page.html?q=1`
- ✅ Idempotent (safe multiple runs)
- ✅ No double slashes
- ✅ Accurate change counting with diff-based tracking
- ✅ Handles `href`, `src`, `url()` in CSS
- ✅ Detailed per-file logging

**Processing:**
1. Domain-absolute URLs → relative: `https://domain.com/path` → `./path`
2. Root-relative → relative: `/path` → `./path`
3. Add `.html` to page links: `./services` → `./services.html` (Python)
4. Clean up double extensions: `page.html.html` → `page.html`

## 🛡️ Validation System

**validate-deploy.sh** performs comprehensive checks:

### Validation Modes

#### 🟢 Soft Mode (Default)
- Root-relative paths → **Warning** (⚠️ )
- Deployment proceeds
- Best for iterative development

#### 🔴 Strict Mode
- Root-relative paths → **Error** (❌)
- Deployment fails and rolls back
- Enable with: `STRICT_VALIDATION=true`

### Checks Performed

| Check | Type | Failure Behavior |
|-------|------|------------------|
| `index.html` exists | Error | Rollback |
| `index.html` > 100 bytes | Error | Rollback |
| File count matches source | Error | Rollback |
| Root-relative paths | Soft: Warn / Strict: Error | Continue / Rollback |
| Base href in subpath | Warning | Continue |
| Double slashes | Warning | Continue |

### Detailed Logging

```bash
# Logs saved to:
/tmp/validation-YYYYMMDD-HHMMSS.log

# JSON report with all issues:
/tmp/path-issues-detail.json
```

**Example JSON output:**
```json
[
  {
    "file": "./index.html",
    "bad_hrefs": ["/about", "/contact"],
    "bad_srcs": ["/images/logo.png"]
  }
]
```

## 📁 Repository Structure

```
.github/
├── workflows/
│   └── deploy.yml          # Main deployment workflow
└── scripts/
    ├── fix-paths.sh        # Path rewriting (v2.7.1+ with Python)
    └── validate-deploy.sh  # Validation (soft/strict modes)
```

**Note:** Repo contains ONLY workflows/scripts. No site content stored here.

## 🔐 Setup

1. **Create PAT** with `contents:write` permission
2. **Add secret** `EXTERNAL_REPO_PAT` to this repo
3. **Run workflow** from Actions tab or via `gh` CLI

## 🐛 Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| Broken CSS/JS | Absolute paths | Check `base_href` matches GitHub Pages URL |
| Links with `?query` broken | Old fix-paths (<v2.7) | Update to v2.7.1+ |
| Links with `#anchor` broken | Old fix-paths (<v2.7) | Update to v2.7.1+ |
| `sed: unknown option to 's'` | v2.7 regex bug | Update to v2.7.1+ (uses Python) |
| Artifact not found | Invalid `run_id` | Verify run_id in source repo Actions |
| Push failed: 403 | PAT permissions | Add `contents:write` to PAT |
| Validation too strict | Default strict mode | Set `STRICT_VALIDATION=false` |
| Want stricter validation | Default soft mode | Set `STRICT_VALIDATION=true` in workflow |
| File count mismatch | Corrupted artifact | Re-run source workflow |

### Debug Mode

```bash
# Enable detailed logging in workflow:
env:
  DEBUG: true
  STRICT_VALIDATION: false  # or true for strict mode
```

## 📊 Changelog

### v2.7.1 (2026-01-01) — CRITICAL Bugfix ⚠️

**fix-paths.sh:**
- 🔥 **CRITICAL FIX:** Replaced broken sed regex with Python script
- ❌ v2.7 had: `sed: -e expression #1, char 27: unknown option to 's'`
- ✅ Python handles complex regex without escaping issues
- ✅ Correctly processes query strings and anchors
- ✅ Production ready - all workflows passing

**If you're on v2.7, update immediately to v2.7.1!**

### v2.7 (2026-01-01) — Major Improvements (DEPRECATED - use v2.7.1)

**fix-paths.sh:**
- ✨ **NEW:** Query string preservation (`?query=value`)
- ✨ **NEW:** Anchor preservation (`#section`)
- ✨ **NEW:** Smart `.html` insertion before queries/anchors
- ❌ **BUG:** sed regex escaping issues - fixed in v2.7.1

**validate-deploy.sh:**
- ✨ **NEW:** Soft validation mode (default)
- ✨ **NEW:** Strict validation mode (`STRICT_VALIDATION=true`)
- ✨ **NEW:** Timestamped log files (`/tmp/validation-*.log`)
- ✨ **NEW:** JSON issue export (`/tmp/path-issues-detail.json`)
- ✨ **NEW:** Per-file issue breakdown with examples
- ✅ Shows first 5 issues per file
- ✅ Counts JS files and more asset types
- ✅ Better formatting with emojis

### v2.6 (2026-01-01) — Critical Bugfixes

**fix-paths.sh:**
- ✅ Idempotent logic - safe multiple runs
- ✅ No double slashes in BASE_HREF
- ✅ Accurate replacement counting
- ✅ Checks existing paths before rewriting

**validate-deploy.sh:**
- ✅ Correct regex for absolute paths
- ✅ Double slash detection
- ✅ Soft warnings vs hard errors
- ✅ Better error reporting

### v2.5 (2025-12-26) — Performance

- 🚀 3-5x faster repository cleanup
- 🚀 Smart empty repo detection

## 🔗 Ecosystem

- [web-crawler](https://github.com/KomarovAI/web-crawler) - Generates site artifacts
- [ai-content-auto-generator](https://github.com/KomarovAI/ai-content-auto-generator) - AI content generation

## 📝 License

MIT - Free for commercial use

---

**⚡ Built for AI-first workflow automation** | Zero local dependencies | Token-efficient documentation
