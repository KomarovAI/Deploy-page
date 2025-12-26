# 🚀 Website Deployment Guide

This guide explains how to deploy archived websites using the automated GitHub Actions workflow.

## Overview

The deployment workflow:
1. 🔍 Downloads website artifacts from web-crawler
2. 🧹 Cleans the target repository completely
3. 📦 Copies all website files
4. 🔧 Fixes all paths for GitHub Pages hosting
5. ✅ Validates the deployment
6. 🚀 Force pushes to the target repository

## Prerequisites

- [ ] `EXTERNAL_REPO_PAT` secret is configured in your GitHub organization
- [ ] The target repository exists and is accessible
- [ ] The web-crawler has completed a successful run with artifacts

## How to Deploy

### Step 1: Get the web-crawler run ID

1. Go to [web-crawler Actions](https://github.com/KomarovAI/web-crawler/actions)
2. Find the completed run you want to deploy
3. Copy the run ID (visible in the URL or run details)

Example run ID: `20479494022`

### Step 2: Trigger the deployment

1. Go to [Deploy-page Actions](https://github.com/KomarovAI/Deploy-page/actions)
2. Select **"Deploy Website to Target Repository"** workflow
3. Click **"Run workflow"** button
4. Fill in the parameters:

| Parameter | Example | Description |
|-----------|---------|-------------|
| `run_id` | `20479494022` | Run ID from web-crawler (numeric value) |
| `target_repo` | `KomarovAI/archived-sites` | Target repository in format `owner/repo` |
| `target_branch` | `main` | Branch to deploy to (default: `main`) |
| `commit_message` | `chore: deploy website` | Commit message for the deployment |
| `base_href` | `/` | Base path for site: `/` for root or `/subpath/` |

### Step 3: Monitor the deployment

1. The workflow will run and display progress
2. Check the **Jobs** section for detailed logs
3. Once complete, check the target repository for deployed files

## What Happens During Deployment

### Phase 1: Validation (🔍)

- Validates all input parameters
- Checks run ID format (must be numeric)
- Validates repository name format (owner/repo)
- Validates base_href format (must start with `/`)

### Phase 2: Download (📦)

- Downloads artifact from web-crawler
- Verifies artifact exists and contains files
- Counts total files and size

### Phase 3: Cleanup (🧹)

- Checks out target repository
- **Removes ALL files except `.git` and `.github`**
- Resets git index to ensure clean state
- Cleans any untracked files

### Phase 4: Deploy (📦)

- Copies all website files from artifact
- Verifies file count matches source
- Creates proper directory structure

### Phase 5: Fix Paths (🔧)

- Converts absolute paths to relative paths
- Example: `href="/page"` → `href="./page"`
- Fixes paths in HTML, CSS, and JavaScript files
- Adds `<base href>` tag if using subpath deployment

### Phase 6: Validate (✅)

- Checks deployed files
- Verifies HTML files exist
- Looks for broken absolute paths
- Displays directory structure

### Phase 7: Commit & Push (🚀)

- Stages all files in git
- Creates commit with timestamp
- Force pushes to target branch
- Displays deployment summary

## Troubleshooting

### Issue: "No changes to commit"

**Cause**: Files already exist in repository with identical content

**Solution**:
- The workflow creates an empty commit (allowed)
- Check if files were actually deployed to the target repo
- Force push will ensure the latest version is deployed

### Issue: "Artifact not found"

**Cause**: Run ID is incorrect or artifact doesn't exist

**Solution**:
1. Verify the run ID from web-crawler is correct
2. Ensure the web-crawler run completed successfully
3. Check that the artifact name matches format: `site_archive-{RUN_ID}`

### Issue: "Invalid repository format"

**Cause**: Repository name not in `owner/repo` format

**Solution**:
1. Check the format: `owner/repo` (no spaces, single slash)
2. Example: `KomarovAI/archived-sites`

### Issue: "Deployment succeeded but site not loading"

**Cause**: Paths not fixed correctly or base_href incorrect

**Solution**:
1. Check if base_href matches your repository name
   - Root deployment: `/`
   - Subpath deployment: `/archived-sites/`
2. Verify GitHub Pages is enabled in target repository
3. Check browser console for broken resource links
4. Redeploy with correct base_href

### Issue: Force push failed

**Cause**: Permission issues or branch protection

**Solution**:
1. Verify `EXTERNAL_REPO_PAT` has write access to target repo
2. Check if branch has force push protection
3. Ensure the token hasn't expired

## File Structure After Deployment

After successful deployment, your target repository will contain:

```
archived-sites/
├── .git/               # Git repository (preserved)
├── .github/            # GitHub configs (preserved)
├── index.html          # Deployed website files
├── css/
│   └── style.css
├── js/
│   └── script.js
└── assets/
    ├── images/
    └── fonts/
```

## Deployment Summary

After each deployment, GitHub Actions generates a summary showing:

- ✅ Deployment status (Success/Failed)
- 📊 Number of files deployed
- 📦 Total artifact size
- 🔗 Links to repository and commits
- ⏰ Deployment timestamp

## Best Practices

1. **Always verify the run ID** before deploying
2. **Test with a test repository first** if deploying for the first time
3. **Use descriptive commit messages** for tracking deployments
4. **Document the base_href** for each repository
5. **Check the workflow logs** if something goes wrong
6. **Verify deployed files** in the target repository after deployment

## Advanced Options

### Custom Commit Message

Use a descriptive commit message:

```
chore: deploy callmedley.com (2025-12-26)
```

This helps track what was deployed and when.

### Subpath Deployment

For deploying to a subpath (e.g., GitHub Pages user site with project repos):

1. Set `base_href` to `/project-name/`
2. The workflow will add `<base href="/project-name/">` to HTML files
3. All relative paths will be converted automatically

### Manual Cleanup

If you need to manually clean a repository:

```bash
cd target-repo
git reset --hard HEAD
git clean -fdx
```

## Support

For issues or questions:

1. Check the workflow logs in GitHub Actions
2. Review this troubleshooting guide
3. Check the web-crawler logs for artifact issues
4. Verify GitHub Pages settings in target repository
