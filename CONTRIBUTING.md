# Contributing to home-pi

## Release Workflow

This project uses an automated package and release workflow based on an **orchestrator pattern**.

### Workflow Architecture

The release process uses two workflows:

1. **`on-tag-main.yml`** - Orchestrator that triggers on tag push
2. **`package-release.yml`** - Worker that builds packages and creates releases

### Workflow Triggers

#### 1. Push a Tag (Automatic) - Recommended

**Most common method** - Push a semver tag to trigger automatic packaging and release:

```bash
# Create and push a tag locally
git tag v0.1.0
git push origin v0.1.0

# Or create via GitHub UI/API
gh release create v0.1.0 --draft
```

**What happens:**
1. `on-tag-main.yml` detects the tag push
2. Automatically finds the previous tag for release notes
3. Triggers `package-release.yml` via GitHub API with proper inputs
4. Builds `.deb` package for arm64
5. Creates a draft GitHub release with artifacts
6. Merges tag back to `main` branch

**Tag format:** Must match `v[0-9]+.[0-9]+.[0-9]+` (e.g., `v0.1.0`, `v1.2.3`)

#### 2. Manual Workflow Dispatch

**Advanced control** - Manually trigger `package-release.yml` via GitHub Actions UI:

```
Actions → Package and Release → Run workflow
```

**Note:** The `package-release.yml` workflow is triggered via `workflow_dispatch`, which means:
- It can be triggered manually through the GitHub UI
- It is automatically triggered via GitHub API by orchestrator workflows (`on-tag-main.yml`, `create-branch-on-minor-tag.yml`)
- It does NOT trigger automatically on push events

**Required inputs:**
- `ref`: Git ref to checkout (e.g., `refs/tags/v0.1.0` - must be a valid version tag)
- `previous`: Previous tag for release notes comparison (e.g., `v0.0.9`)

**Optional inputs:**
- `source_branch`: Branch to merge the tag back to (e.g., `main`)

**What happens:**
- ✅ Validates that `ref` is a properly formatted version tag
- ✅ Builds `.deb` package for arm64
- ✅ Uses your specified previous tag for release notes
- ✅ Creates a draft GitHub release with artifacts
- ✅ Optionally merges tag back to source branch (if `source_branch` provided)

#### 3. Merge to Release Branch (Not Yet Implemented)

Currently, merging a PR to a release branch (e.g., `v0.1.x`) does NOT automatically trigger the workflow. This is a planned feature.

### How the Orchestrator Pattern Works

When you push a tag:

1. **`on-tag-main.yml` triggers** (runs on `main` branch)
   - Detects tag push via `push: tags: v[0-9]+.[0-9]+.[0-9]+`
   - Checks out the repository with full history
   - Finds previous tag using `git describe --tags --abbrev=0 HEAD^`
   - Calls GitHub API to dispatch `package-release.yml`

2. **API dispatch parameters:**
   ```json
   {
     "ref": "main",  // Branch to run workflow from
     "inputs": {
       "ref": "refs/tags/v0.1.0",  // Tag to build
       "previous": "v0.0.9",  // Previous tag for release notes
       "source_branch": "main"  // Branch to merge back to
     }
   }
   ```

3. **`package-release.yml` executes** with provided inputs

**Why this pattern?** GitHub Actions reads workflow files from the default branch, not from tags. The orchestrator ensures the workflow runs with the correct context.

### Workflow Jobs

The `package-release.yml` workflow consists of three jobs:

#### Job 1: `package-deb`
- Checks out the specified tag/ref
- Extracts version information
- Prepares package structure (scripts, udev rules, maintainer scripts)
- Builds Debian package using `jiro4989/build-deb-action@v4`
- Uploads `.deb` as artifact

#### Job 2: `release`
- Downloads `.deb` artifacts from `package-deb`
- Uses provided previous tag for release notes comparison
- Generates release notes comparing current tag with previous tag
- Creates a **draft** GitHub release with:
  - Version number as release name
  - Generated release notes
  - `.deb` package artifacts

#### Job 3: `merge-back` (Conditional)
- **Only runs** when `source_branch` input is provided
- Checks out the source branch
- Imports GPG key for signed commits
- Merges the tag back to the source branch:
  - Attempts fast-forward merge first
  - Falls back to merge commit if fast-forward not possible
- Pushes updated branch to origin

### Required Configuration

**Repository Workflow Permissions:**

The orchestrator pattern requires the `GITHUB_TOKEN` to have write permissions to trigger workflows.

**Using GitHub CLI (Recommended):**

```bash
# Set workflow permissions to read and write
gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  /repos/asnowfix/home-pi/actions/permissions \
  -F enabled=true \
  -f default_workflow_permissions='write' \
  -F can_approve_pull_request_reviews=false

# Verify the configuration
gh api \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  /repos/asnowfix/home-pi/actions/permissions
```

**Expected verification output:**
```json
{
  "enabled": true,
  "allowed_actions": "all",
  "sha_pinning_required": false
}
```

**Using GitHub Web UI:**

1. Go to: https://github.com/asnowfix/home-pi/settings/actions
2. Under "Workflow permissions", select **"Read and write permissions"**
3. Save changes

**Why this is needed:** By default, new repositories have read-only `GITHUB_TOKEN` permissions. The orchestrator needs write permissions to dispatch `package-release.yml` via API. Without this, you'll get a 403 error when the orchestrator tries to trigger the package workflow.

### Required Secrets

- `GITHUB_TOKEN` - Automatically provided by GitHub Actions (used for workflow dispatch and release creation)
- `GPG_PRIVATE_KEY` - For signing commits during merge-back (optional, only needed if using merge-back feature)
- `GPG_PASSPHRASE` - Passphrase for GPG key (optional, only needed if using merge-back feature)

#### Setting Up GPG Secrets (Optional)

If you want to use the merge-back feature with signed commits, configure GPG secrets:

**Using GitHub CLI:**

```bash
# List your GPG keys to find the key ID
gpg --list-secret-keys --keyid-format=long
# Look for the line starting with 'sec' - the key ID is after the key type
# Example: sec   rsa4096/ABCD1234EFGH5678 2024-01-01
#          The key ID is: ABCD1234EFGH5678

# Export your GPG private key (replace YOUR_KEY_ID with the actual key ID from above)
gpg --armor --export-secret-keys YOUR_KEY_ID > private-key.asc

# Set GPG_PRIVATE_KEY secret
gh secret set GPG_PRIVATE_KEY --repo asnowfix/home-pi < private-key.asc

# Set GPG_PASSPHRASE secret
gh secret set GPG_PASSPHRASE --repo asnowfix/home-pi
# (You'll be prompted to enter the passphrase)

# Clean up the exported key file
rm private-key.asc

# Verify secrets were added
gh secret list --repo asnowfix/home-pi
```

**Using GitHub Web UI:**

1. Go to: https://github.com/asnowfix/home-pi/settings/secrets/actions
2. Click "New repository secret"
3. Add `GPG_PRIVATE_KEY` with your exported private key
4. Add `GPG_PASSPHRASE` with your key passphrase

### Release Process

**Standard release flow:**

1. **Prepare release** on a release branch (e.g., `v0.1.x`)
   ```bash
   git checkout -b v0.1.x
   # Make changes, commit
   git push origin v0.1.x
   ```

2. **Create and push tag**
   ```bash
   git tag v0.1.0
   git push origin v0.1.0
   ```

3. **Workflow runs automatically**
   - Builds package
   - Creates draft release

4. **Review and publish release**
   - Go to GitHub Releases
   - Review draft release
   - Edit release notes if needed
   - Publish release

5. **Optional: Merge back to main** (manual workflow dispatch)
   - Go to Actions → Package and Release → Run workflow
   - Set `ref`: `refs/tags/v0.1.0`
   - Set `previous`: `v0.0.9`
   - Set `source_branch`: `main`
   - Run workflow

### Package Details

**Package name:** `usb-automount`

**Architecture:** `arm64` (Raspberry Pi)

**Dependencies:**
- `udev`
- `python3 (>= 3.7)`
- `python3-pip`
- `python3-venv`

**Package contents:**
- `/usr/local/bin/usb-automount.sh` - Main automount script
- `/etc/udev/rules.d/99-usb-automount.rules` - udev rules
- Maintainer scripts: `postinst`, `prerm`, `postrm`

### Troubleshooting

**Workflow fails on release notes generation:**
- Check that both current and previous tags exist
- Verify `GITHUB_TOKEN` has correct permissions

**Merge-back fails:**
- Ensure `GPG_PRIVATE_KEY` and `GPG_PASSPHRASE` secrets are configured
- Check that source branch exists
- Verify no merge conflicts exist

**Package build fails:**
- Verify all required files exist: `usb-automount.sh`, `99-usb-automount.rules`, `debian/*.sh`
- Check file permissions on maintainer scripts

## Development Workflow

1. Create feature branch from `main`
2. Make changes and commit
3. Create PR to `main` or release branch
4. After merge, create tag to trigger release
5. Review and publish draft release

## Version Numbering

This project follows [Semantic Versioning](https://semver.org/):

- **MAJOR** version for incompatible API changes
- **MINOR** version for backwards-compatible functionality additions
- **PATCH** version for backwards-compatible bug fixes

Tags must be prefixed with `v` (e.g., `v1.2.3`).
