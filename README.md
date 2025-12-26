**ВНИМАНИЕ: ЭТОТ РЕПОЗИТОРИЙ — ИСКЛЮЧИТЕЛЬНО ДЛЯ ИИ.**
**РЕЖИМ:** token-first (максимальная экономия токенов).
**ЗАПРЕЩЕНО:** плодить сущности, разводить грязь документацией, создавать ненужные файлы/папки/конфиги.

**ВНИМАНИЕ: ЭТОТ РЕПОЗИТОРИЙ — ИСКЛЮЧИТЕЛЬНО ДЛЯ GitHub Actions WORKFLOW И RUNNER-ОВ.**
Разрешено только то, что напрямую нужно для работы workflow/runner.

## Разрешено (строго)
- `.github/workflows/*.yml`
- `.github/scripts/*` (короткие скрипты, вызываемые ИЗ workflow)
- `.github/actions/*` (локальные actions — только если без них нельзя)
- служебное: `README.md`, `.github/CODEOWNERS`, `.github/dependabot.yml`, `LICENSE`

## Запрещено (без исключений)
- Dockerfile, docker-compose.*, devcontainer, buildpacks, container actions
- k8s/helm/terraform/ansible и любая инфраструктурная мишура
- `docs/`, "полные гайды", дублирующие документы
- `src/`, "примерчики", ассеты, любые файлы "просто чтобы было"
- дублирующие workflow (одна задача — один workflow; параметризуй, если надо)

## Карта проекта (единственная)
- `.github/workflows/` — автоматизация
- `.github/scripts/` — скрипты для шагов workflow
- `.github/actions/` — локальные actions (редко)
- `README.md` — правила (single source of truth)

## Правила для ИИ (обязательно)
- Пиши кратко: заголовок → 3–7 буллетов → 0–1 пример.
- Не повторяй одно и то же в разных местах (single source of truth).
- Новый файл/папка = по умолчанию запрещено. Если "без этого нельзя" — объяснение в 1 строку в PR/коммите.

## Минимальная безопасность GitHub Actions
- `GITHUB_TOKEN`: least privilege; повышать permissions только точечно на job/step.
- Секреты: никаких plaintext в workflow; только GitHub Secrets.
- Сторонние actions: по возможности фиксировать на полный commit SHA (supply chain).
- `.github/workflows/**` — только через ревью (CODEOWNERS/branch protection).


## 📄 Workflows Documentation

### pages.yml
**Trigger:** `push` (main branch) + `workflow_dispatch`  
**Purpose:** Build and deploy GitHub Pages  
**Runs:** ubuntu-latest  

**Features:**
- Generates static site (index.html)
- Uploads to GitHub Pages artifact
- Deploys to GitHub Pages environment

### deploy-site.yml
**Trigger:** `workflow_dispatch` (manual only)  
**Purpose:** Deploy website to target repository  
**Runs:** ubuntu-latest  

**Workflow Inputs:**
- `artifact_name` (required): Full artifact name (e.g., `site_archive-12345678`)
- `target_repo` (required): Target repository (format: `owner/repo`)
- `target_branch` (optional, default: `main`): Target branch for deployment
- `commit_message` (optional, default: `chore: deploy website`): Custom commit message

**Workflow Steps:**
1. Validates all inputs (regex checks)
2. Downloads artifact from GitHub Actions
3. Verifies artifact (file count, size)
4. Cleans target repository (removes all except `.git`, `.github`, `.gitignore`, `README.md`, `LICENSE`)
5. Deploys website files
6. Commits and pushes to target branch
7. Outputs deployment summary

**Requirements:**
- `EXTERNAL_REPO_PAT` secret must be configured in repository settings
  - GitHub Personal Access Token with `contents:write` permission for target repository
  - How to create: Settings → Developer settings → Personal access tokens → Tokens (classic) → Generate new token (classic)

**Example Usage:**
```bash
# 1. Create artifact from another workflow
# 2. Copy artifact name (e.g., site_archive-20479494022)
# 3. Go to Deploy-page Actions tab
# 4. Click deploy-site.yml → Run workflow
# 5. Enter parameters:
#    - artifact_name: site_archive-20479494022
#    - target_repo: owner/repo-name
#    - target_branch: main
#    - commit_message: (optional)
```

---

## 🔐 Secrets Configuration

### Required Secrets
- **EXTERNAL_REPO_PAT**: GitHub Personal Access Token
  - Scope: `repo:write` (contents:write for target repository)
  - Used by: deploy-site.yml workflow
  - Storage: Repository Settings → Secrets and variables → Actions

### How to Set Up
1. Go to target repository Settings
2. Navigate to Secrets and variables → Actions
3. Click "New repository secret"
4. Name: `EXTERNAL_REPO_PAT`
5. Value: Your GitHub Personal Access Token
6. Click "Add secret"

---

