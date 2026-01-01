# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.0.0] - 2026-01-01 🎉 MAJOR RELEASE

### 🔥 Breaking Changes
- **COMPLETE PYTHON REWRITE** - all bash scripts converted to Python
- Scripts now use `#!/usr/bin/env python3` shebang (but keep `.sh` extension for compatibility)
- Requires Python 3.6+ on GitHub Actions runners (already available)

### ✨ Added
- **BeautifulSoup4 integration** - proper HTML/CSS DOM parsing
- **Auto-dependency installation** - scripts install BeautifulSoup if missing
- **urllib.parse** - correct URL/query string handling in fix-paths.sh
- **JSON logging** - structured validation reports
- **ANSI color support** - beautiful console output
- **Object-oriented architecture** - classes for PathFixer, StaticSiteFixer, DeploymentValidator
- **Type hints** - better code documentation

### 🔧 Refactored Scripts

#### fix-static-site.sh → Python
- `StaticSiteFixer` class with proper HTML parsing
- BeautifulSoup replaces sed/grep for script injection
- No more "unterminated 's' command" errors
- Handles ALL special characters safely
- Cleaner logging with emoji

#### fix-paths.sh → Python
- `PathFixer` class with URL parsing
- urllib.parse for query strings and anchors
- BeautifulSoup for HTML attribute modification
- Proper CSS `url()` handling with regex
- Idempotent by design

#### validate-deploy.sh → Python
- `DeploymentValidator` class
- BeautifulSoup for accurate path detection
- JSON report generation
- Color-coded console output
- Structured logging to /tmp/validation-*.log

### ✅ Improvements
- **No sed/awk/grep fragility** - Python handles escaping automatically
- **Better error messages** - full stack traces on failures
- **Unit-testable code** - can import and test classes directly
- **Maintainable** - readable Python vs cryptic bash
- **Faster execution** - single-pass HTML parsing

### 📚 Technical Details

**Before (bash):**
```bash
sed -i "s|</body>|${JS_FIX}\n</body>|" "$file"  # ❌ Breaks on special chars
grep -E 'href="/[^/]' "$file"  # ❌ Regex hell
```

**After (Python):**
```python
soup = BeautifulSoup(content, "html.parser")
body_tag.append(script_tag)  # ✅ DOM manipulation
tag["href"] = fix_url(tag["href"])  # ✅ Clean attribute update
```

### 🚨 Migration Guide

**No action required!** Scripts are backward-compatible:
- Workflow calls remain unchanged (bash .github/scripts/*.sh)
- Shebang automatically invokes Python
- Dependencies auto-install on first run
- Exit codes identical to bash versions

**Benefits:**
- Existing workflows work immediately
- No more sed failures
- Better debugging with Python tracebacks

### 🧰 Testing

All scripts tested on:
- Ubuntu 24.04 (GitHub Actions runner)
- Python 3.10+
- With and without BeautifulSoup pre-installed
- Various HTML/CSS edge cases

---

## [2.8.1] - 2026-01-01 ⚠️ CRITICAL (DEPRECATED)

### Fixed
- 🔥 **CRITICAL:** Fixed `fix-static-site.sh` script injection failure
- ❌ v2.8.0 had: `sed: -e expression #1, char 45: unterminated 's' command`
- ✅ Replaced `sed` with `perl` for safe JavaScript injection
- ✅ Added `awk` fallback for maximum compatibility

**NOTE:** v2.8.1 is now obsolete - upgrade to v3.0.0 for full Python solution.

---

## [2.8.0] - 2026-01-01 🎉 (DEPRECATED)

### Added
- **NEW SCRIPT:** `fix-static-site.sh` for WordPress static export processing
- **Navigation Fix:** Injects click handler to override legacy WordPress JS
- **Legacy JS Removal:** Auto-removes Autoptimize cache, comment-reply.js, wp-embed.js

**Known Issues:**
- ❌ **BUG:** sed injection fails with special characters (fixed in v3.0.0)

---

## [2.7.1] - 2026-01-01 ⚠️ CRITICAL (DEPRECATED)

### Fixed
- 🔥 **CRITICAL:** Replaced broken sed regex with Python script in `fix-paths.sh`
- ✅ Python handles complex regex without shell escaping issues

---

## [2.7.0] - 2026-01-01 (DEPRECATED)

### Added
- **Query String Preservation:** `href="/page?q=1"` → `href="./page.html?q=1"`
- **Anchor Preservation:** `href="/page#top"` → `href="./page.html#top"`

---

## [2.6.0] - 2026-01-01

### Fixed
- **Idempotent path fixing** - safe to run multiple times
- **BASE_HREF trailing slashes** - no more `//` in URLs

---

## [2.5.0] - 2025-12-26

### Added
- **Smart empty repo detection**
- **Performance metrics**

---

## [2.4.0] - 2025-12-26

### Added
- **Full repository wipe** - deletes ALL content except `.github`
- **Commit deletions** - explicitly commits file removals

---

## [2.3.0] - 2025-12-26

### Added
- **Python-based .html extension logic**

---

## [2.2.0] - 2025-12-26

### Added
- **Snapshot-based rollback**
- **Step-by-step validation**

---

## [2.1.0] - 2025-12-26

### Added
- **Artifact auto-detection**
- **Subpath deployment support**

---

## [2.0.0] - 2025-12-26

### Added
- **Artifact-based deployment**
- **Cross-repository support**

### Breaking Changes
- Removed support for direct source repo deployment

---

## [1.0.0] - 2025-12-25

### Added
- Initial release
- Basic deployment workflow

---

## Legend

- 🎉 Major feature release
- ⚠️ Critical bugfix required
- 🐛 Bug fix
- ✨ New feature
- 🔥 Breaking change
- 🚀 Performance improvement
- ✅ Improvement
- ❌ Known issue
- ℹ️ Information
