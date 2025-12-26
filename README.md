# Deploy-page

**ВНИМАНИЕ: ЭТОТ РЕПОЗИТОРИЙ — ИСКЛЮЧИТЕЛЬНО ДЛЯ ИИ.**  
**РЕЖИМ:** token-first (максимальная экономия токенов).  
**ЗАПРЕЩЕНО:** плодить сущности, разводить грязь документацией, создавать ненужные файлы/папки/конфиги.

---

## 🎯 Что здесь

`.github/workflows/deploy-site.yml` — deploy сайтов на целевой репо из artifact'ов  
`.github/scripts/fix-paths.sh` — переписывает абсолютные пути на относительные для GitHub Pages

---

## 📋 deploy-site.yml

**Trigger:** `workflow_dispatch` (ручной запуск)

**Inputs:**
- `run_id` (обязательно) — artifact name типа `site_archive-20479494022`
- `target_repo` (обязательно) — формат `owner/repo`
- `target_branch` (опционально, default: `main`) — ветка для deploy'а
- `commit_message` (опционально) — сообщение коммита
- `base_href` (опционально, default: `/`) — базовый путь для сайта

**Что делает:**
1. Валидирует inputs (regex, trim spaces, format checks)
2. Скачивает artifact из web-crawler
3. Проверяет целостность (file count, size)
4. Очищает целевой репо (сохраняет `.git`, `.github`, `README.md`, `LICENSE`)
5. Копирует файлы сайта
6. Переписывает пути (absolute → relative для Pages)
7. Коммитит и пушит с error handling
8. Создает summary в Actions UI

**Outputs:**
- `deploy_status` — `committed`, `no_changes`, или error
- `deployed_files` — количество файлов
- `commit_sha` — SHA коммита

---

## 🔧 fix-paths.sh

**Вызывается из:** deploy-site.yml шаг "Fix paths for GitHub Pages"

**Что делает:**
- HTML: `href="/path"` → `href="./path"`, `src="/image"` → `src="./image"`
- CSS: `url(/img.png)` → `url(./img.png)`
- JS: `require('/mod')` → `require('./mod')`, `fetch('/api')` → `fetch('./api')`
- Валидация оставшихся абсолютных путей
- Детальное логирование

---

## 🔐 Secrets

**EXTERNAL_REPO_PAT** — GitHub Personal Access Token с правами `contents:write`

Добавить: Settings → Secrets and variables → Actions → New secret

---

## 🆘 Troubleshooting

| Ошибка | Причина | Решение |
|--------|---------|----------|
| Artifact not found | run_id неверный или artifact удален | Проверить ID, artifact должны жить 30 дней |
| Push failed | Нет прав или branch protection | Проверить token, branch rules, allow github-actions[bot] |
| Invalid target_repo | Формат не `owner/repo` | Убедиться: ровно 2 сегмента, нет пробелов |
| No changes | Artifact совпадает с целевым репо | OK — deployment идемпотентен |

---

## ✅ v2.0.0 Changes

**Critical fixes:**
- ✅ Fixed regex в fix-paths.sh (был broken → invalid HTML)
- ✅ Added error handling для git push
- ✅ Improved input validation (trim, strict format)
- ✅ Added timeout 10 min (safety guard)

**New:**
- ✅ `base_href` parameter для GitHub Pages subpaths
- ✅ Deployment summary в Actions UI
- ✅ Output variables для automation

---

## 🔗 Related

- **web-crawler** — генерирует artifacts для deploy'а
- [GitHub Actions docs](https://docs.github.com/en/actions)
- [GitHub Pages docs](https://docs.github.com/en/pages)

---

*Last updated: 2025-12-26 — v2.0 production ready*
