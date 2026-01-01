# 🚀 Deploy-page

> **🤖 AI-OPTIMIZED REPOSITORY** | Token-first design | Workflow-only execution | Zero local dependencies

[![AI-First](https://img.shields.io/badge/AI-First%20Repository-blueviolet?style=for-the-badge&logo=openai)](https://github.com/KomarovAI/Deploy-page)
[![Token-Efficient](https://img.shields.io/badge/Token-Efficient-green?style=for-the-badge)](https://github.com/KomarovAI/Deploy-page)
[![Workflow-Only](https://img.shields.io/badge/Execution-Workflow%20Only-orange?style=for-the-badge&logo=github-actions)](https://github.com/KomarovAI/Deploy-page)

**Automated static site deployment to GitHub Pages** through GitHub Actions workflow orchestration with artifact-based content delivery, intelligent path rewriting, and zero-downtime rollback mechanisms.

---

## ⚡ Quick Deploy

```bash
# Root deployment
gh workflow run deploy.yml -f run_id=12345 -f target_repo=user/repo

# Subpath deployment
gh workflow run deploy.yml -f run_id=12345 -f target_repo=user/repo -f base_href="/project/"
```

## 🎯 Core Features

- **Artifact Orchestration** - Pull from any GitHub Actions run
- **Smart Path Rewriting** - Absolute → relative (GitHub Pages compatible)
- **Idempotent Scripts** - Safe to run multiple times
- **Automatic Rollback** - Git snapshot restoration on failure
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
<script src="https://example.com/app.js">

<!-- After (root) -->
<link href="./styles.css">
<script src="./app.js">

<!-- After (subpath /project/) -->
<link href="/project/styles.css">
<script src="/project/app.js">
```

**Features:**
- ✅ Idempotent (safe multiple runs)
- ✅ No double slashes (`/project//path` → `/project/path`)
- ✅ Accurate replacement counting
- ✅ Handles `href`, `src`, `url()` in CSS

## 🛡️ Validation

**validate-deploy.sh** checks:
- File count integrity
- Double slash detection (indicates bugs)
- Base href presence for subpath
- Broken absolute paths
- Directory structure correctness

**Validation modes:**
- 🔴 **Hard fail** - Missing index.html, file count mismatch, double slashes
- 🟡 **Soft warning** - Absolute paths in subpath deployment

## 📁 Repository Structure

```
.github/
├── workflows/deploy.yml    # Main deployment workflow
└── scripts/
    ├── fix-paths.sh        # Path rewriting (idempotent)
    └── validate-deploy.sh  # Deployment validation
```

**Note:** Repo contains ONLY workflows/scripts. No site content stored here.

## 🔐 Setup

1. **Create PAT** with `contents:write` permission
2. **Add secret** `EXTERNAL_REPO_PAT` to this repo
3. **Run workflow** from Actions tab

## 🐛 Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| Broken CSS/JS | Absolute paths | Check `base_href` matches GitHub Pages URL |
| Artifact not found | Invalid `run_id` | Verify run_id in source repo Actions |
| Push failed: 403 | PAT permissions | Add `contents:write` to PAT |
| Double slashes | Path fixing bug | Fixed in v2.6 (2026-01-01) |
| File count mismatch | Corrupted artifact | Re-run source workflow |

## 📊 Changelog

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