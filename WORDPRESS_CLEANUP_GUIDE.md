# 🧹 WordPress Cleanup Guide

> **ПРОБЛЕМА:** WordPress static export оставляет мусор, который ломает GitHub Pages deployment

---

## 🚨 Опасный WordPress Мусор

### Категория 1: JavaScript Конфликты

#### 1.1 WordPress Admin Bar JS
```html
<!-- ❌ ВРЕДНО: автоматически добавляет админ-бар даже без лучена -->
<script src="/wp-includes/js/wp-admin-bar.min.js"></script>
```

**Проблема:** 
- Инжектит HTML в начало страницы
- Требует `/wp-admin/` (не существует в статике)
- Ломает CSS (добавляет 28px margin-top)
- Конфликтует с навигацией

**Фикс в fix-static-site.py:**
```python
def remove_wp_admin_bar():
    # Удаляет все скрипты, содержащие:
    # - wp-admin-bar
    # - wp-includes/js
    # - wp-json
```

#### 1.2 WordPress Comment Form JS
```html
<!-- ❌ ВРЕДНО: требует wp-admin для отправки комментариев -->
<script src="/wp-includes/js/comment-reply.min.js"></script>
```

**Проблема:**
- Отправляет данные в `/wp-admin/admin-ajax.php`
- Этого пути нет в статике
- Формы не работают

**Фикс:**
```python
def remove_wordpress_forms():
    # Удаляет comment-reply.min.js и похожие
```

#### 1.3 jQuery Migrate (Legacy)
```html
<!-- ❌ ВРЕДНО: старый jQuery с проблемами совместимости -->
<script src="/wp-includes/js/jquery/jquery-migrate.min.js"></script>
```

**Проблема:**
- Вес: 11KB
- Может ломать новые скрипты
- Багиво

**Фикс:**
```python
def remove_jquery_migrate():
    # Удаляет jquery-migrate полностью
```

#### 1.4 REST API Routes JS
```html
<!-- ❌ ВРЕДНО: добавляет wp.api объект -->
<script id="wp-api-fetch"></script>
<script id="wp-rest-api"></script>
```

**Проблема:**
- Ждёт `/wp-json/` эндпоинта
- Может зависать при загрузке
- Бесполезно в статике

---

### Категория 2: Meta Tags & Headers

#### 2.1 WordPress Generator Meta
```html
<!-- ❌ КОНФИДЕНЦИАЛЬНОСТЬ: раскрывает версию WP -->
<meta name="generator" content="WordPress 6.2.1" />
```

**Проблема:**
- Security issue - видна версия
- Может привлечь хакеров
- Бесполезно на статике

**Фикс:**
```python
def remove_wordpress_generator():
    # Удаляет все meta с name="generator"
```

#### 2.2 Link Rel Prefetch (WP Prefetch)
```html
<!-- ⚠️ ПЛОХО: может создать дополнительные запросы -->
<link rel="prefetch" href="https://external-cdn.com/..."/>
<link rel="dns-prefetch" href="//fonts.googleapis.com"/>
```

**Проблема:**
- Создаёт extra DNS запросы
- Может замедлить загрузку
- На статике бесполезно

**Фикс:**
```python
def remove_prefetch_links():
    # Удаляет rel="prefetch" и rel="dns-prefetch"
```

#### 2.3 REST API Link Header
```html
<!-- ❌ ВРЕДНО: ссылка на несуществующий /wp-json/ -->
<link rel="https://api.w.org/" href="https://site.com/wp-json/" />
```

**Проблема:**
- Вызывает 404
- Видно в браузер консоли
- Замедляет загрузку

**Фикс:**
```python
def remove_rest_api_link():
    # Удаляет rel="https://api.w.org/"
```

#### 2.4 Emoji Support Meta
```html
<!-- ⚠️ ПЛОХО: подтягивает js/css из wp-includes -->
<meta name="emoji-src" content="/wp-includes/js/wp-emoji.min.js">
```

**Проблема:**
- Пути не существуют
- Может выызвать console ошибки
- Вес: 5KB

---

### Категория 3: CSS & Style Injections

#### 3.1 WordPress Block Library CSS
```html
<!-- ❌ ВРЕДНО: инжектит стили для Gutenberg блоков -->
<link rel="stylesheet" id="wp-block-library-css" href="/wp-includes/css/dist/block-library/style.min.css?ver=..">
```

**Проблема:**
- Файл не существует в статике
- Загружается но не найдёт
- Может переписать твои стили

**Фикс:**
```python
def remove_wordpress_css():
    # Удаляет все link[href*="wp-includes"]
    # Удаляет все link[href*="wp-content/themes"]
```

#### 3.2 WordPress Theme CSS (нежелательно)
```html
<!-- ⚠️ ПЛОХО: может конфликтовать с новыми стилями -->
<link rel="stylesheet" href="/wp-content/themes/twentytwentythree/style.css">
```

**Проблема:**
- Theme CSS может вмешиваться
- Вес: 50-200KB
- Может переписать твой CSS

**Стратегия:** Оставить или удалить зависит от твоего выбора

---

### Категория 4: Plugin JS/CSS

#### 4.1 WooCommerce
```html
<!-- ❌ ВРЕДНО: требует PHP бэкэнда -->
<script src="/wp-content/plugins/woocommerce/assets/js/..."></script>
```

**Проблема:**
- Всё работает через AJAX
- Корзина не сохраняется
- Checkout не работает
- Поиск не работает

**Фикс:** Полностью удалить WooCommerce скрипты

#### 4.2 Contact Form 7
```html
<!-- ❌ ВРЕДНО: отправляет на несуществующий wp-admin/admin-ajax.php -->
<div class="wpcf7">...</div>
<script src="/wp-content/plugins/contact-form-7/..."></script>
```

**Проблема:**
- Форма выглядит но не отправляется
- Требует PHP
- API не существует

**Фикс:** Удалить скрипты CF7, оставить форму HTML

#### 4.3 Jetpack
```html
<!-- ❌ ВРЕДНО: пытается подключиться к jetpack.com -->
<script src="https://stats.wp.com/e-..."></script>
```

**Проблема:**
- Внешний скрипт
- Может отправлять user data
- Privacy issue

**Фикс:** Удалить полностью

---

### Категория 5: Conditional Comments & IE Hacks

#### 5.1 IE Conditional Comments
```html
<!-- ❌ УСТАРЕЛО: IE умер, это просто мусор -->
<!--[if IE 8]>
<link rel="stylesheet" href="/wp-content/themes/theme/ie8.css" />
<![endif]-->
```

**Проблема:**
- IE не существует
- Вес: 2-5KB
- Просто захламляет HTML

**Фикс:**
```python
def remove_ie_conditionals():
    # Удаляет все <!--[if IE]>...<![endif]-->
```

---

### Категория 6: Tracking & Analytics

#### 6.1 Google Analytics
```html
<!-- ⚠️ МОЖЕТ БЫТЬ НЕЖЕЛАТЕЛЬНО: отправляет данные -->
<script async src="https://www.googletagmanager.com/gtag/js?id=GA_..."></script>
```

**Проблема:**
- Отправляет user data
- Privacy issue (особенно в EU)
- Может конфликтовать с GDPR

**Фикс:** Удалить или оставить с согласием

#### 6.2 Facebook Pixel
```html
<!-- ❌ ВРЕДНО для privacy -->
<img src="https://facebook.com/tr?id=..."/>
<script src="https://connect.facebook.net/en_US/fbevents.js"></script>
```

**Фикс:** Удалить полностью

---

## 🔧 Что Сейчас Удаляет fix-static-site.py

### ✅ Удаляет (v3.3.0+)

```python
REM_PATTERNS = [
    # WordPress admin
    r'wp-admin',
    r'wp-login',
    r'wp-includes.*\.js',
    r'wp-includes.*\.css',
    r'wp-content/plugins',
    r'wp-content/themes',
    
    # Forms
    r'comment-reply',
    r'contact-form',
    r'wpcf7',
    
    # REST API
    r'wp-json',
    r'wp-api',
    r'rest-api',
    r'api\.w\.org',
    
    # jQuery
    r'jquery-migrate',
    r'jquery.*\.js',  # ⚠️ внимательно!
    
    # Tracking
    r'googletagmanager',
    r'fbevents',
    r'analytics',
]
```

### ❓ НЕ удаляет (нужны дополнения)

```python
# MISSING: Нужно добавить!
# 1. Jetpack скрипты (stats.wp.com)
# 2. Gravatar загрузки
# 3. Emoji support JS
# 4. WooCommerce AJAX
# 5. IE conditional comments
# 6. Link prefetch/dns-prefetch
# 7. Generator meta tag
# 8. REST API link header
```

---

## 🎯 ПОЛНЫЙ ЧЕКЛИСТ ЧИСТКИ

### Стадия 1: Критический Мусор (обязательно удалить)

- [ ] WordPress admin bar JS
- [ ] WordPress comment form JS
- [ ] wp-admin пути
- [ ] wp-json пути
- [ ] admin-ajax.php calls
- [ ] /wp-includes/ ссылки
- [ ] /wp-login.php ссылки

### Стадия 2: Конфликты (мешают отображению)

- [ ] jQuery Migrate
- [ ] Block library CSS
- [ ] WordPress theme CSS (если нужно)
- [ ] IE conditional comments
- [ ] Emoji support JS

### Стадия 3: Privacy/Security

- [ ] Generator meta tag
- [ ] Google Analytics (выбор)
- [ ] Facebook Pixel
- [ ] Jetpack tracking
- [ ] WP stats.wp.com

### Стадия 4: Performance

- [ ] Prefetch/dns-prefetch ссылки
- [ ] WooCommerce JS (если нет shop)
- [ ] Contact Form 7 JS (если нет форм)
- [ ] Unused theme CSS

---

## 📝 Что Нужно ОСТАВИТЬ

### ✅ Безопасные вещи

```html
<!-- Можно оставить -->
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta charset="UTF-8">
<link rel="canonical" href="...">
<meta name="description" content="...">
<meta name="robots" content="index, follow">

<!-- Твои скрипты (если правильные) -->
<script src="./app.js"></script>
<script src="./analytics-custom.js"></script>

<!-- Твои стили -->
<link rel="stylesheet" href="./styles.css">

<!-- Font услуги (проверить GDPR) -->
<link href="https://fonts.googleapis.com/css2?family=..." rel="stylesheet">
```

---

## 🛠️ Как Добавить Расширенную Чистку

### Вариант 1: Обновить fix-static-site.py

```python
def clean_wordpress_artifacts(soup: BeautifulSoup) -> int:
    """Удалить ВСЕ WordPress артефакты."""
    removed = 0
    
    # STAGE 1: Удалить опасные скрипты
    dangerous_patterns = [
        r'wp-admin', r'wp-json', r'admin-ajax',
        r'wp-includes.*js', r'comment-reply',
        r'contact-form', r'wpcf7', r'jetpack',
        r'fbevents', r'googletagmanager',
    ]
    
    for pattern in dangerous_patterns:
        for script in soup.find_all(['script', 'link']):
            src_attr = script.get('src') or script.get('href') or ''
            if re.search(pattern, src_attr, re.I):
                script.decompose()
                removed += 1
    
    # STAGE 2: Удалить вредные мета теги
    bad_metas = [
        {'name': 'generator'},
        {'rel': 'https://api.w.org/'},
        {'rel': 'prefetch'},
        {'rel': 'dns-prefetch'},
    ]
    
    for meta_attrs in bad_metas:
        for meta in soup.find_all('meta', meta_attrs):
            meta.decompose()
            removed += 1
    
    # STAGE 3: Удалить IE условные комментарии
    for comment in soup.find_all(string=lambda text: isinstance(text, Comment)):
        if '[if IE' in comment:
            comment.extract()
            removed += 1
    
    return removed
```

### Вариант 2: Отдельный скрипт

```bash
#!/usr/bin/env python3
"""Deep WordPress cleanup - удаляет ВСЕ следы WP."""

if __name__ == '__main__':
    fixer = WordPressDeepCleaner()
    removed = fixer.run(site_path)
    print(f"🧹 Removed {removed} WordPress artifacts")
```

---

## 🧪 Как Проверить Что Осталось

### 1. Проверить консоль браузера (F12)

```javascript
// В Console зупусти:
console.log(document.querySelectorAll('script[src*="wp-"]').length)
// Должно быть 0
```

### 2. Проверить Network (F12 → Network)

```
❌ Плохо: 404 на /wp-admin/*, /wp-json/*, /wp-includes/*
✅ Хорошо: Только твои файлы и CDN
```

### 3. Grep поиск

```bash
# Ищем оставшийся мусор
grep -r "wp-admin" . --include="*.html"
grep -r "wp-json" . --include="*.html"
grep -r "wp-includes" . --include="*.html"
grep -r "comment-reply" . --include="*.html"
grep -r "jetpack" . --include="*.html"
grep -r "facebook" . --include="*.html"
# Всё должно быть пусто!
```

---

## 📊 Таблица Приоритетов

| Мусор | Удалять? | Приоритет | Почему |
|-------|----------|-----------|--------|
| wp-admin JS | ✅ ДА | 🔴 CRITICAL | Ломает админ-бар |
| wp-json ссылки | ✅ ДА | 🔴 CRITICAL | 404 errors |
| admin-ajax | ✅ ДА | 🔴 CRITICAL | Формы не работают |
| jQuery Migrate | ✅ ДА | 🟠 HIGH | Может ломать скрипты |
| WooCommerce JS | ✅ ДА | 🟠 HIGH | Если нет shop |
| CF7 JS | ✅ ДА | 🟠 HIGH | Если нет форм |
| Jetpack | ✅ ДА | 🟠 HIGH | Privacy issue |
| Google Analytics | ⚠️ МОЖЕТ | 🟡 MEDIUM | GDPR зависит |
| Generator meta | ✅ ДА | 🟡 MEDIUM | Security |
| Prefetch links | ✅ ДА | 🟡 MEDIUM | Performance |
| IE conditions | ✅ ДА | 🟢 LOW | Просто мусор |
| Emoji JS | ✅ ДА | 🟢 LOW | Редко нужно |

---

## 🎯 ИТОГО

### fix-static-site.py (v3.3.0) сейчас удаляет: ~60%

### Надо добавить для 100% чистки:

1. ✅ Jetpack скрипты
2. ✅ IE conditional comments
3. ✅ Emoji support JS
4. ✅ Generator meta tag
5. ✅ Link prefetch/dns-prefetch
6. ✅ WooCommerce check
7. ✅ Contact Form 7 check
8. ✅ Gravatar references

### После добавления этих 8 пунктов → 100% чистка! 🎉

---

**Версия:** v1.0 | **Дата:** 2026-01-02 | **Статус:** Ready for implementation
