# Deploy-page: AI-Optimized GitHub Actions Deployment

**ВНИМАНИЕ: ЭТОТ РЕПОЗИТОРИЙ — ИСКЛЮЧИТЕЛЬНО ДЛЯ ИИ.**
**РЕЖИМ:** token-first (максимальная экономия токенов).  
**ЗАПРЕЩЕНО:** плодить сущности, разводить грязь документацией, создавать ненужные файлы/папки/конфиги.

**ВНИМАНИЕ: ЭТОТ РЕПОЗИТОРИЙ — ИСКЛЮЧИТЕЛЬНО ДЛЯ GitHub Actions WORKFLOW И RUNNER-ОВ.**
Разрешено только то, что напрямую нужно для работы workflow/runner.

---

## 🎯 Разрешено (строго)
- `.github/workflows/*.yml` — automation workflows
- `.github/scripts/*` — короткие скрипты, вызываемые ИЗ workflow
- `.github/actions/*` — локальные actions (только если без них нельзя)
- служебное: `README.md`, `.github/CODEOWNERS`, `.github/dependabot.yml`, `LICENSE`

## 🚫 Запрещено (без исключений)
- Dockerfile, docker-compose.*, devcontainer, buildpacks, container actions
- k8s/helm/terraform/ansible и любая инфраструктурная мишура
- `docs/`, "полные гайды", дублирующие документы
- `src/`, "примерчики", ассеты, любые файлы "просто чтобы было"
- дублирующие workflow (одна задача — один workflow; параметризуй, если надо)

---

## 📊 Карта проекта (единственная)
```
.github/
├── workflows/
│   └── deploy-site.yml       ← Deploy на целевой репозиторий
├── scripts/
│   └── fix-paths.sh          ← Переписывает пути для GitHub Pages
├── CODEOWNERS                ← Правила ревью (если нужно)
└── dependabot.yml            ← Auto-updates (опционально)
```

---

## 📋 Правила для ИИ (обязательно)
- Пиши кратко: заголовок → 3–7 буллетов → 0–1 пример.
- Не повторяй одно и то же в разных местах (single source of truth).
- Новый файл/папка = по умолчанию запрещено. Если "без этого нельзя" — объяснение в 1 строку в PR/коммите.

---

## 🔐 Минимальная безопасность GitHub Actions
- `GITHUB_TOKEN`: least privilege; повышать permissions только точечно на job/step.
- Секреты: никаких plaintext в workflow; только GitHub Secrets.
- Сторонние actions: по возможности фиксировать на полный commit SHA (supply chain).
- `.github/workflows/**` — только через ревью (CODEOWNERS/branch protection).

---

## 📄 Workflows Documentation

### deploy-site.yml
**Trigger:** `workflow_dispatch` (manual only)  
**Purpose:** Deploy website to target repository  
**Runs:** ubuntu-latest  
**Timeout:** 10 minutes (safety guard)  

**Workflow Inputs:**
| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `run_id` | Yes | - | Full artifact name (e.g., `site_archive-12345678`) |
| `target_repo` | Yes | - | Target repository (format: `owner/repo`) |
| `target_branch` | No | `main` | Target branch for deployment |
| `commit_message` | No | `chore: deploy website` | Custom commit message |
| `base_href` | No | `/` | Base path for site (e.g., "/" or "/project-name/") |

**Workflow Steps:**
1. **Validate inputs** — regex checks + trim + format validation
2. **Download artifact** — from GitHub Actions (cross-repo)
3. **Verify artifact** — file count, size, integrity
4. **Wipe target repository** — preserve `.git`, `.github`, `.gitignore`, `README.md`, `LICENSE`
5. **Deploy website** — copy files to target repo
6. **Fix paths** — rewrite absolute paths to relative for GitHub Pages
7. **Commit and push** — with error handling and validation
8. **Create summary** — deployment report in GitHub Actions UI

**Output Variables:**
- `deploy_status` — `committed`, `no_changes`, or error
- `deployed_files` — number of files deployed
- `commit_sha` — commit SHA if successful

**Example Usage:**
```bash
# 1. Create artifact from another workflow
# 2. Copy artifact name (e.g., site_archive-20479494022)
# 3. Go to Deploy-page Actions tab
# 4. Click deploy-site.yml → Run workflow
# 5. Enter parameters:
#    - run_id: 20479494022
#    - target_repo: owner/repo-name
#    - target_branch: main
#    - commit_message: "chore: deploy from web-crawler"
#    - base_href: "/" (for root) or "/project/" (for subpath)
```

---

## 🔧 Scripts Documentation

### fix-paths.sh
**Purpose:** Rewrite absolute paths to relative paths for GitHub Pages  
**Called by:** `deploy-site.yml` step "Fix paths for GitHub Pages"

**What it does:**
- Processes **HTML files**: rewrites `href="/path"` → `href="./path"` and `src="/path"` → `src="./path"`
- Processes **CSS files**: rewrites `url(/path)` → `url(./path)`
- Processes **JavaScript files**: rewrites `require('/path')` → `require('./path')`, `fetch('/path')` → `fetch('./path')`, etc.
- Includes **validation** to detect remaining absolute paths
- Provides **detailed logging** with file counts and statistics

**Key Improvements (v2.0):**
- ✅ Fixed broken regex that was creating invalid HTML
- ✅ Proper capture groups for robust path rewriting
- ✅ Handles both single and double quotes
- ✅ Processes data-* attributes, import statements, XMLHttpRequest
- ✅ Validation step to find missed absolute paths
- ✅ Comprehensive logging and error reporting

**Example Output:**
```
🔧 Starting path fixing for GitHub Pages...
📋 Scanning files...
  Found: 42 HTML, 12 CSS, 8 JS files
📝 Processing HTML files...
  ✓ Fixed index.html
  ✓ Fixed pages/about.html
...
✅ Path fixing completed successfully

📋 Summary:
  - HTML files processed: 42
  - CSS files processed: 12
  - JS files processed: 8
  - Relative paths detected: 156
```

---

## 🔐 Secrets Configuration

### Required Secrets
**EXTERNAL_REPO_PAT** (GitHub Personal Access Token)
- **Scope:** `repo:write` (specifically: contents:write for target repository)
- **Used by:** `deploy-site.yml` workflow
- **Storage:** Repository Settings → Secrets and variables → Actions

### How to Create
1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Configure scopes:
   - ✅ `repo` (all of it, or specifically `contents:write` if fine-grained tokens supported)
   - ✅ `workflow` (if needed for cross-repo workflow triggers)
4. Copy token value
5. Add to Deploy-page repo:
   - Settings → Secrets and variables → Actions → New repository secret
   - Name: `EXTERNAL_REPO_PAT`
   - Value: [paste token]

### Security Best Practices
- Use **fine-grained tokens** (if available) with minimal scopes
- Rotate tokens every 90 days
- Use separate tokens for different environments (prod/staging)
- Never commit secrets to repository
- Monitor token usage via audit logs

---

## 🛠️ Troubleshooting

### ❌ "Artifact not found or empty"
**Cause:** Artifact doesn't exist in web-crawler repo or name is wrong

**Solutions:**
1. Check run_id is correct: `https://github.com/KomarovAI/web-crawler/actions/runs/{run_id}`
2. Verify artifact name matches: `site_archive-{run_id}`
3. Ensure EXTERNAL_REPO_PAT has access to web-crawler repo
4. Check artifact retention: GitHub purges old artifacts (default 30 days)

---

### ❌ "Push to {branch} failed"
**Cause:** Git push error - usually permissions or branch protection

**Solutions:**
1. **Check token permissions:**
   - EXTERNAL_REPO_PAT must have `contents:write` for target repo
   - Create new token if needed

2. **Check branch protection rules:**
   - Settings → Branches → Branch protection rules
   - Verify github-actions[bot] is allowed
   - May need to disable "Require pull request reviews" for bot commits

3. **Check branch exists:**
   - Verify target_branch exists on target repo
   - Use default `main` if unsure

4. **Check network:**
   - Verify GitHub API is accessible
   - Check firewall/proxy settings

---

### ❌ "Invalid target repository format"
**Cause:** target_repo doesn't match `owner/repo` format

**Solutions:**
1. Check format: must be exactly `owner/repo` (no spaces, no extra slashes)
2. Examples of valid formats:
   - `john/my-site`
   - `org-name/project`
   - `my_org/site-prod`

3. Invalid formats:
   - ` john/my-site ` (has spaces - should trim)
   - `john/my-site/extra` (has 3 segments)
   - `john-site` (missing slash)

---

### ⚠️ "No changes to commit"
**Status:** ℹ️ Not an error - just informational

**Meaning:**
- Deployment completed successfully
- But artifact content matches target repo content
- No new files to commit

**Action:** None needed - deployment is idempotent

---

### ❌ "fix-paths.sh script not found"
**Cause:** Deploy-page checkout failed or script path is wrong

**Solutions:**
1. Verify `.github/scripts/fix-paths.sh` exists in Deploy-page repo
2. Check workflow checkout step completed successfully
3. Verify GITHUB_WORKSPACE variable is correct

---

## 📈 Monitoring & Debugging

### View Deployment History
1. Go to Deploy-page repo
2. Click Actions tab
3. Click deploy-site.yml
4. See all historical deployments

### Check Deployment Details
1. Click specific workflow run
2. Expand each step to see logs
3. Check "Create deployment summary" step for final report
4. Links to target repo and commits included

### Enable Debug Logging
Add to workflow before running:
```bash
export ACTIONS_STEP_DEBUG=true
```

Or set in repository Settings → Secrets:
```
ACTIONS_STEP_DEBUG=true
```

---

## ✅ Recent Improvements (Dec 2025)

**Critical Fixes:**
- ✅ Fixed broken regex in fix-paths.sh (was creating invalid HTML)
- ✅ Added error handling for git push (fail workflow on push failure)
- ✅ Improved input validation (trim spaces, strict format checks)
- ✅ Added timeout-minutes: 10 (prevent hanging workflows)

**New Features:**
- ✅ Customizable base_href parameter for different deployment scenarios
- ✅ Deployment summary in GitHub Actions UI (with links and status)
- ✅ Better error messages and troubleshooting hints
- ✅ Output variables for automation (deploy_status, deployed_files, commit_sha)
- ✅ Enhanced logging with file counts and processing details

**Quality Improvements:**
- ✅ Comprehensive path fixing for HTML, CSS, JS, data attributes
- ✅ Validation step to detect missed absolute paths
- ✅ Better handling of edge cases (empty repos, missing scripts, etc.)

---

## 📚 Related Resources

### Official GitHub Documentation
- [GitHub Actions docs](https://docs.github.com/en/actions)
- [GitHub Pages docs](https://docs.github.com/en/pages)
- [Artifact storage](https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/storing-workflow-data-as-artifacts)
- [Environments and secrets](https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions)

### Related Projects
- **web-crawler:** Generates artifacts for deployment
- **Target repos:** Receive deployed content via this workflow

---

## 📞 Support

For issues or questions:
1. Check Troubleshooting section above
2. Review workflow logs in Actions tab
3. Enable debug logging if needed
4. Check target repository settings (branch protection, secrets)

---

*Last updated: 2025-12-26*  
*Status: ✅ Production Ready (v2.0 with critical fixes)*
