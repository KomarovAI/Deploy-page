# Changelog

## [2.3.0] - 2025-12-26

### 🚀 What's New

#### Complete Repository Cleanup
- **Feature**: Full repository cleanup before deployment
- **What it does**: Removes ALL files except `.git` and `.github` directories
- **Why**: Guarantees clean state, prevents file accumulation, ensures idempotent deployments
- **How it works**:
  ```bash
  find . -mindepth 1 -maxdepth 1 -not -name '.git' -not -name '.github' -exec rm -rf {} +
  git reset --hard HEAD
  git clean -fdx
  git reset HEAD --hard
  ```

#### Deployment Validation Script
- **New file**: `.github/scripts/validate-deploy.sh`
- **Purpose**: Validate deployed website integrity after deployment
- **Checks**:
  - ✅ Total file count and size
  - ✅ Presence of `index.html`
  - ✅ No broken absolute paths remaining
  - ✅ Directory structure validation
  - ✅ Proper file distribution

#### Improved Workflow
- **New step**: "Validate deployment" runs after path fixing
- **Better logging**: Each step now has clear emoji indicators
- **Enhanced error handling**: More informative error messages
- **Timeout increased**: From 10 to 15 minutes for larger deployments

#### Documentation
- **New file**: `DEPLOY.md` - Comprehensive deployment guide
- **Updated**: `README.md` with v2.3 features
- **Added**: This changelog

### 🔧 Improvements

#### Workflow Robustness
- `fetch-depth: 0` for target repo checkout (full history)
- Multiple git reset/clean stages for maximum safety
- Empty commit support when no changes exist
- Better git status output before/after cleanup

#### Logging & Visibility
- Detailed logs at each deployment phase
- Color-coded output with emoji indicators
- Comprehensive summary in GitHub Actions UI
- File count and size tracking

#### Error Prevention
- Better input validation with detailed error messages
- Source artifact verification with file counting
- Copy verification (source/destination file count matching)
- Path fixing validation with error checking

### 📊 Changes Made

#### `.github/workflows/deploy-site.yml`
```diff
+ timeout-minutes: 15  # Increased from 10

+ - name: Validate deployment  # NEW STEP
+   id: validate_deploy
+   run: bash validate-deploy.sh

+ fetch-depth: 0  # Full git history for target repo

+ Better cleanup with hard reset and multiple clean stages

+ fetch-depth: 0  # Get full git history
+ git reset HEAD --hard  # Additional safety reset

+ timestamp tracking in commits
```

#### `.github/scripts/validate-deploy.sh` (NEW)
- Validates deployed files count
- Checks `index.html` exists and reports size
- Scans for remaining absolute paths
- Displays directory structure
- File type statistics (HTML, CSS, JS, etc.)

#### `DEPLOY.md` (NEW)
- **Step-by-step deployment guide**
- Prerequisites checklist
- Input parameters explanation
- Detailed phase breakdown (validation → cleanup → deploy → validate)
- Troubleshooting guide with solutions
- File structure reference
- Best practices
- Advanced options (custom messages, subpath deployment, manual cleanup)

#### `README.md` (UPDATED)
- Added cleanup strategy section
- Updated version to v2.3.0
- Added `validate-deploy.sh` documentation
- Enhanced changelog section
- Better formatting and organization

#### `CHANGELOG.md` (NEW - THIS FILE)
- Complete history of changes
- Detailed explanation of v2.3 improvements
- Links to related documentation

### 🔐 Security Enhancements

- **Hard reset** instead of soft reset for git safety
- **Double reset** (after clean, before commit) for guarantees
- **Force clean** with `-fdx` flags
- **File validation** at multiple checkpoints
- **No temporary files** left in working directory

### 🔗 Deployment Phases (Now 7 phases)

1. **Validate inputs** (regex, formats, normalization)
2. **Download artifact** (from web-crawler)
3. **Verify artifact** (file count, size, integrity)
4. **Clean repository** 📦 **[NEW]** - Complete cleanup
5. **Copy files** (from artifact to target repo)
6. **Fix paths** (absolute → relative + base href)
7. **Validate deployment** ✅ **[NEW]** - Integrity check
8. **Commit & Push** (force push to target branch)

### 🧐 Why These Changes?

#### Why Complete Cleanup?

**Problem**: When deploying multiple times to the same repository, old files could accumulate if the structure changed (e.g., old files deleted in new build).

**Solution**: Remove everything except git metadata and GitHub config.

**Benefits**:
- ✅ 100% guaranteed clean state
- ✅ No file accumulation
- ✅ Idempotent deployments
- ✅ No conflicts or merge issues
- ✅ Fresh start every time

#### Why Validation?

**Problem**: You deploy successfully but don't know if the website actually loaded correctly or if paths are broken.

**Solution**: Run validation script to check deployed website integrity.

**Benefits**:
- ✅ Immediate feedback on deployment quality
- ✅ Early detection of path issues
- ✅ File count verification
- ✅ Directory structure validation
- ✅ Peace of mind

### 🔄 Migration Guide (v2.2 → v2.3)

No breaking changes! If you're using v2.2:

1. Pull latest changes
2. Workflow runs automatically with improvements
3. Your deployments get:
   - Complete cleanup (better!)
   - Validation (better!)
   - More timeout (better!)
   - Better logging (better!)

**No action needed from you!** Everything is backwards compatible.

### 📋 Files Added/Modified

| File | Status | Purpose |
|------|--------|----------|
| `.github/workflows/deploy-site.yml` | 🔄 Modified | Cleanup, validation, better logging |
| `.github/scripts/validate-deploy.sh` | ✨ New | Post-deployment validation |
| `DEPLOY.md` | ✨ New | Comprehensive deployment guide |
| `README.md` | 🔄 Updated | v2.3 features documentation |
| `CHANGELOG.md` | ✨ New | This file - version history |

### 🚃 Known Issues

None! All features are production-ready.

### 🕵️ Future Considerations

- [ ] Support for multiple artifact formats
- [ ] Automated testing before deployment
- [ ] Rollback capability
- [ ] Deployment statistics tracking
- [ ] Slack notifications on deployment
- [ ] Pre/post deployment hooks

### 🚆 Contributors

- @KomarovAI - Implementation and testing

### 🔗 Links

- **Full Deployment Guide**: [DEPLOY.md](./DEPLOY.md)
- **Repository README**: [README.md](./README.md)
- **Web Crawler**: [KomarovAI/web-crawler](https://github.com/KomarovAI/web-crawler)

---

## [2.2.0] - 2025-12-19

### Features
- Path fixing script with BASE_HREF support
- Automated path conversion (absolute → relative)
- Base href insertion for subpath deployments
- Full GitHub Pages support

### Improvements
- Centralized path fixing logic
- Better environment variable handling
- Improved logging

---

## [2.1.0] - 2025-12-12

### Initial Release
- Basic deployment workflow
- Artifact download and verification
- Simple file copying
- Git commit and push

---

*For detailed deployment instructions, see [DEPLOY.md](./DEPLOY.md)*
