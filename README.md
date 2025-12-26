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
