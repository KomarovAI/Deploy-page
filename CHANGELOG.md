# Changelog

All notable changes to Deploy-page project are documented in this file.

## [2.0.0] - 2025-12-26

### 🚉 Critical Fixes
- **fix: fix-paths.sh regex bug** - Fixed broken sed pattern that was creating invalid HTML
  - Replaced `s|\"/[a-zA-Z]|\".\/&|g` with proper capture groups
  - Now correctly handles href, src, data-* attributes with both single and double quotes
  - Added validation to detect remaining absolute paths
  - Files: `.github/scripts/fix-paths.sh`

- **fix: add error handling to git push** - Workflow now fails if push is unsuccessful
  - Check git push exit code and fail immediately on error
  - Display helpful error messages (branch protection, permissions, network)
  - Prevent silent failures in deployment
  - Files: `.github/workflows/deploy-site.yml`

- **fix: improve input validation** - Stricter validation with better error messages
  - Trim leading/trailing spaces from target_repo
  - Validate exactly 2 segments (owner/repo)
  - Check base_href format
  - Provide examples in error messages
  - Files: `.github/workflows/deploy-site.yml`

### ✨ New Features
- **feat: add base_href parameter** - Support deployments to different paths
  - New workflow input: `base_href` (default: "/")
  - Auto-configured for root Pages (/) or subpath (/project-name/)
  - Fixes HTML base tag handling
  - Files: `.github/workflows/deploy-site.yml`

- **feat: add deployment summary** - GitHub Actions UI report with details
  - Shows deployment status, files, commit SHA
  - Links to target repository and commits
  - Timestamps and clear success/failure indicators
  - Files: `.github/workflows/deploy-site.yml`

- **feat: add workflow timeout** - Safety guard against hanging workflows
  - `timeout-minutes: 10` on deploy job
  - Prevents runaway git operations
  - Saves runner-minutes
  - Files: `.github/workflows/deploy-site.yml`

- **feat: output deployment variables** - Automation-friendly outputs
  - `deploy_status` - committed, no_changes, or error
  - `deployed_files` - count of deployed files
  - `commit_sha` - commit SHA on success
  - Files: `.github/workflows/deploy-site.yml`

### 💪 Improvements
- **improve: fix-paths.sh logging** - Detailed output for debugging
  - File count statistics (HTML, CSS, JS processed)
  - Per-file change indicators
  - Validation summary with absolute path detection
  - Better error handling with set -e

- **improve: error messages** - More helpful troubleshooting info
  - Examples of valid/invalid formats
  - Specific guidance on what went wrong
  - Links to relevant documentation
  - Files: `.github/workflows/deploy-site.yml`

- **improve: JavaScript path handling** - Support more patterns
  - require('/path') → require('./path')
  - fetch('/path') → fetch('./path')
  - import/from statements
  - XMLHttpRequest patterns
  - Files: `.github/scripts/fix-paths.sh`

- **improve: CSS path handling** - Better url() detection
  - url(/path/to/file) → url(./path/to/file)
  - url("/path") variants with quotes
  - Both modern and legacy CSS
  - Files: `.github/scripts/fix-paths.sh`

### 📊 Documentation
- **docs: comprehensive README** - Complete workflow documentation
  - Detailed input parameter documentation
  - Workflow steps explanation
  - Script behavior documentation
  - Security best practices
  - Token creation guide
  - Files: `README.md`

- **docs: troubleshooting guide** - Common issues and solutions
  - Artifact not found / empty
  - Git push failures
  - Invalid input formats
  - Token permission issues
  - Branch protection conflicts
  - Files: `README.md`

- **docs: monitoring section** - How to check deployments
  - View deployment history
  - Check deployment details
  - Enable debug logging
  - Files: `README.md`

- **docs: CHANGELOG** - Track all changes
  - This file

### 🕒 Performance
- Reduced logging verbosity while maintaining useful output
- Optimized sed patterns for faster processing
- Parallel processing capability in fix-paths.sh

### 🔐 Security
- Enhanced input validation prevents injection attacks
- Better secret handling documentation
- Fine-grained token guidance
- Token rotation recommendations

---

## [1.0.0] - 2025-12-24

### 🌟 Initial Release
- GitHub Pages deployment workflow from artifacts
- Cross-repository deployment support
- Artifact verification and validation
- Repository cleanup and deployment
- Path fixing for absolute to relative URLs
- Token-based authentication (EXTERNAL_REPO_PAT)
- Git configuration and commit/push

---

## Upgrade Guide

### From v1.0.0 to v2.0.0

**Breaking Changes:** None - fully backward compatible

**Migration Steps:**
1. Update Deploy-page repository (automatic with pull)
2. No changes needed to target repositories
3. No changes needed to workflow inputs (new base_href is optional)
4. Tokens and secrets remain the same

**Benefits After Update:**
- ✅ More reliable deployments (error handling)
- ✅ Better visibility (summary reports)
- ✅ Fewer broken links (improved path fixing)
- ✅ Faster error detection (input validation)
- ✅ Customizable paths (base_href parameter)

**Testing Recommendation:**
1. Create test repository
2. Run deploy workflow with new code
3. Verify deployment succeeded
4. Check for any broken links
5. Proceed with production deployments

---

## Known Issues

### None Currently
If you encounter issues, check Troubleshooting section in README.md

---

## Future Roadmap

### Planned Features
- [ ] Dry-run mode (preview without pushing)
- [ ] Slack/Telegram notifications
- [ ] Automatic rollback on health check failure
- [ ] Multi-target deployment (matrix strategy)
- [ ] Artifact retention optimization
- [ ] Performance metrics reporting

### Under Consideration
- [ ] GitHub Issues integration
- [ ] Deployment approvals
- [ ] Blue-green deployments
- [ ] A/B testing support
- [ ] Webhook notifications

---

## Contributing

This repository follows strict token-efficiency and single-responsibility principles.

Before adding features:
1. Check if it's truly necessary
2. Ensure no code duplication
3. Keep files minimal and focused
4. Document in README (single source of truth)
5. Test on actual deployments

---

## Support

For questions or issues:
1. Check README.md Troubleshooting section
2. Review workflow logs in Actions tab
3. Enable debug logging if needed
4. Examine target repository settings

---

*Semver: [MAJOR.MINOR.PATCH](https://semver.org/)*  
*Format: Based on [Keep a Changelog](https://keepachangelog.com/)*
