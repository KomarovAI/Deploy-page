# 📦 Website Archiving Guide

## Overview

This repository provides a complete solution for archiving websites with **all resources intact** including CSS, JavaScript, images, fonts, and other assets.

## Features

- ✅ **Complete HTML preservation** with proper structure
- ✅ **CSS files downloaded** (external and inline)
- ✅ **JavaScript files included**
- ✅ **Images, fonts, and media** saved locally
- ✅ **Relative path fixing** for offline viewing
- ✅ **Recursive crawling** within same domain
- ✅ **GitHub Actions automation**

## Quick Start

### Using GitHub Actions (Recommended)

1. Go to **Actions** → **Archive Website**
2. Click **Run workflow**
3. Enter:
   - Website URL
   - Crawl depth (0-3)
   - Target branch name
4. Wait for completion
5. Check the `archived-sites` branch

### Using Script Locally

```bash
# Install dependencies
pip install -r scripts/requirements.txt

# Archive a website
python scripts/archive_site.py https://example.com \
  --output ./output \
  --depth 2
```

## Parameters

### URL
Full website URL to archive (must include protocol)

**Examples:**
- `https://example.com`
- `https://docs.example.com/guide`
- `http://old-site.org`

### Depth

Controls how deep the crawler goes:

- `0` - Only the specified page
- `1` - Page + directly linked pages
- `2` - Up to 2 clicks away (recommended)
- `3` - Up to 3 clicks away (may take time)

### Output Structure

```
archived_sites/
└── example.com/
    ├── index.html
    ├── about.html
    ├── style.css
    ├── script.js
    ├── images/
    │   ├── logo.png
    │   └── banner.jpg
    ├── fonts/
    │   └── font.woff2
    └── archive_metadata.json
```

## How It Works

### 1. HTML Processing
- Downloads HTML content
- Parses with BeautifulSoup
- Identifies all resource links

### 2. Resource Download
- **CSS files:** Downloaded and paths fixed for `url()` references
- **JavaScript:** Saved locally
- **Images:** All formats (jpg, png, svg, webp, etc.)
- **Fonts:** woff, woff2, ttf, otf
- **Other:** Any linked resources

### 3. Path Resolution
- Converts absolute URLs to relative paths
- Maintains directory structure
- Handles query strings safely
- Fixes CSS `url()` references

### 4. Recursive Crawling
- Follows links within same domain
- Respects depth limit
- Avoids duplicate downloads
- Rate-limited (0.5s delay)

## Metadata File

Each archive includes `archive_metadata.json`:

```json
{
  "base_url": "https://example.com",
  "archived_at": "2026-01-01 12:00:00 UTC",
  "total_pages": 15,
  "total_resources": 87,
  "pages": [
    "https://example.com",
    "https://example.com/about"
  ]
}
```

## Best Practices

### For Small Sites
```bash
python scripts/archive_site.py https://small-site.com --depth 2
```

### For Large Sites
```bash
# Start with depth 0 or 1
python scripts/archive_site.py https://large-site.com --depth 1
```

### For Documentation Sites
```bash
# Use depth 2-3 for complete docs
python scripts/archive_site.py https://docs.example.com --depth 3
```

## Troubleshooting

### Missing CSS

**Problem:** CSS not applied  
**Solution:** Check browser console for 404s. Script should download all CSS automatically.

### Broken Images

**Problem:** Images not loading  
**Solution:** Verify image URLs in metadata. Some sites use JavaScript to load images dynamically.

### Slow Archiving

**Problem:** Takes too long  
**Solution:** Reduce depth or archive specific pages only.

### Permission Errors

**Problem:** Site blocks archiving  
**Solution:** Some sites block automated access. Respect robots.txt.

## Advanced Usage

### Custom Output Directory
```bash
python scripts/archive_site.py https://example.com \
  --output /custom/path
```

### Archive Specific Page
```bash
# Depth 0 = single page only
python scripts/archive_site.py https://example.com/specific-page \
  --depth 0
```

### Multiple Sites
```bash
# Archive multiple sites
for url in site1.com site2.com site3.com; do
  python scripts/archive_site.py "https://$url" --depth 1
done
```

## GitHub Pages Deployment

Archived sites can be deployed to GitHub Pages:

1. Archive site to `archived-sites` branch
2. Enable GitHub Pages from that branch
3. Access at `https://yourusername.github.io/repo-name/domain.com/`

## Limitations

- **JavaScript-heavy sites:** Dynamic content may not render correctly
- **Authentication:** Cannot archive password-protected pages
- **Rate limits:** Large sites may trigger rate limiting
- **SPA applications:** Single-page apps may not archive properly

## Examples

### WordPress Site
```bash
python scripts/archive_site.py https://wordpress-site.com --depth 2
```

### Documentation
```bash
python scripts/archive_site.py https://docs.python.org/3/ --depth 1
```

### Blog
```bash
python scripts/archive_site.py https://blog.example.com --depth 3
```

## See Also

- [README.md](../README.md) - Project overview
- [DEPLOY.md](../DEPLOY.md) - Deployment guide
- [CHANGELOG.md](../CHANGELOG.md) - Version history
