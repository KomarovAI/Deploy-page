# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.8.0] - 2026-01-01 🎉

### Added
- **NEW SCRIPT:** `fix-static-site.sh` for WordPress static export processing
- **Navigation Fix:** Injects click handler to override legacy WordPress JS
- **Legacy JS Removal:** Auto-removes Autoptimize cache, comment-reply.js, wp-embed.js
- **WordPress Artifact Cleanup:** Removes xmlrpc.php, wp-cron.php, wp-login files
- **Theme JS Detection:** Flags files with `preventDefault()` conflicts
- **Idempotent Injection:** Checks for existing fixes before patching HTML
- **Detailed Logging:** Step-by-step output with emoji formatting
- **Summary Statistics:** Tracks files removed, patched, and flagged

### Changed
- **Workflow:** Added Step 10.5 "Fix static site issues" between path fixing and validation
- **README.md:** Added comprehensive documentation for WordPress static site fixes
- **README.md:** Added troubleshooting section for common WordPress export issues

### Fixed
- 🐛 **Fast clicks not working** on WordPress static exports (legacy JS hijacking events)
- 🐛 **Navigation broken** by `e.preventDefault()` in theme JavaScript
- 🐛 **404 errors** on wp-login.php, xmlrpc.php, and other WordPress dynamic files
- 🐛 **Path conflicts** from Autoptimize cache expecting WordPress directory structure

### Technical Details

The click handler fix uses:
- **Capturing phase** event listener (`addEventListener(..., true)`) - executes BEFORE other handlers
- **stopImmediatePropagation()** - prevents all other click handlers from executing
- **Simple navigation** - `window.location.href` with no animations or delays
- **Smart targeting** - only affects internal `.html` links
- **Modifier key support** - respects Ctrl/Cmd+Click for opening in new tabs

---

## [2.7.1] - 2026-01-01 ⚠️ CRITICAL

### Fixed
- 🔥 **CRITICAL:** Replaced broken sed regex with Python script in `fix-paths.sh`
- ❌ v2.7 had: `sed: -e expression #1, char 27: unknown option to 's'`
- ✅ Python handles complex regex without shell escaping issues
- ✅ Correctly processes query strings and anchors
- ✅ Production ready - all workflows passing

### Migration

**If you're on v2.7, update immediately to v2.7.1!**

No breaking changes - drop-in replacement.

---

## [2.7.0] - 2026-01-01 (DEPRECATED)

### Added
- **Query String Preservation:** `href="/page?q=1"` → `href="./page.html?q=1"`
- **Anchor Preservation:** `href="/page#top"` → `href="./page.html#top"`
- **Smart .html Insertion:** Adds extension before query strings and anchors
- **Soft Validation Mode:** Default mode with warnings instead of hard failures
- **Strict Validation Mode:** Enable with `STRICT_VALIDATION=true`
- **Timestamped Logs:** `/tmp/validation-YYYYMMDD-HHMMSS.log`
- **JSON Issue Export:** `/tmp/path-issues-detail.json` for programmatic parsing
- **Per-file Issue Breakdown:** Shows first 5 issues per file in validation

### Changed
- **validate-deploy.sh:** Improved formatting with emojis and better structure
- **validate-deploy.sh:** Now counts JavaScript files separately
- **validate-deploy.sh:** Better detection of asset types (CSS, JS, images)

### Known Issues
- ❌ **BUG:** sed regex escaping issues in `fix-paths.sh` (fixed in v2.7.1)

---

## [2.6.0] - 2026-01-01

### Fixed
- **Idempotent path fixing** - now safe to run multiple times without double-processing
- **BASE_HREF trailing slashes** - no more `//` in URLs
- **Accurate replacement counting** - uses diff-based tracking instead of sed output
- **Duplicate path rewriting** - checks if paths already correct before modifying
- **Absolute path detection** - correct regex in validate-deploy.sh
- **Double slash detection** - properly identifies `//` in paths

### Changed
- **fix-paths.sh:** Now checks existing content before applying transformations
- **fix-paths.sh:** Better logging with per-file change counts
- **validate-deploy.sh:** Separated soft warnings from hard errors
- **validate-deploy.sh:** Improved error reporting with context

---

## [2.5.0] - 2025-12-26

### Added
- **Smart empty repo detection** - skips cleanup if repository is already empty
- **Performance metrics** in deployment summary

### Changed
- **Repository cleanup** - 3-5x faster with optimized `find` commands
- **Repository cleanup** - Better handling of `.github` directory exclusion

### Fixed
- **Cleanup step** - no longer fails on empty repositories

---

## [2.4.0] - 2025-12-26

### Added
- **Full repository wipe** - deletes ALL content except `.github` before deployment
- **Commit deletions** - explicitly commits file removals (critical for GitHub Pages)
- **Nested artifact extraction** - handles artifacts with single subdirectory
- **File count validation** - ensures source and destination match
- **Detailed deployment summary** - shows file count, size, commit SHA

### Changed
- **Workflow structure** - reorganized steps for better clarity
- **Error handling** - improved rollback on validation failures

### Fixed
- **Orphaned files** - no longer accumulate from previous deployments
- **Directory structure** - properly extracts nested artifact contents

---

## [2.3.0] - 2025-12-26

### Added
- **Python-based .html extension logic** - replaces fragile sed regex
- **Query parameter support** - preserves `?query=value` in URLs
- **Anchor support** - preserves `#section` in URLs

### Changed
- **fix-paths.sh:** Major refactor to use Python for complex transformations

---

## [2.2.0] - 2025-12-26

### Added
- **Snapshot-based rollback** - automatic revert on failure
- **Step-by-step validation** - comprehensive pre-deployment checks
- **Deployment summary** - detailed success/failure reporting

---

## [2.1.0] - 2025-12-26

### Added
- **Artifact auto-detection** - pattern matching for `*-{run_id}`
- **Subpath deployment support** - `BASE_HREF` parameter
- **Workflow input validation** - regex checks for all parameters

---

## [2.0.0] - 2025-12-26

### Added
- **Artifact-based deployment** - no more source repo cloning
- **Cross-repository support** - deploy from any workflow
- **Smart path fixing** - converts absolute to relative URLs
- **GitHub Pages compatibility** - automatic `.html` extension addition

### Changed
- **Complete workflow rewrite** - artifact orchestration instead of git operations

### Breaking Changes
- Removed support for direct source repo deployment
- Now requires artifact upload in source workflow

---

## [1.0.0] - 2025-12-25

### Added
- Initial release
- Basic deployment workflow
- Repository cloning and copying
- Simple path fixing

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
