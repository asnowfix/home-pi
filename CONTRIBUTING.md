# Contributing to home-pi

## Release Workflow

This project uses an automated package and release workflow that supports multiple trigger methods.

### Workflow Triggers

The `Package and Release` workflow (`.github/workflows/package-release.yml`) can be triggered in three ways:

#### 1. Push a Tag (Automatic)

**Most common method** - Push a semver tag to trigger automatic packaging and release:

```bash
# Create and push a tag locally
git tag v0.1.0
git push origin v0.1.0

# Or create via GitHub UI/API
gh release create v0.1.0 --draft
```

**What happens:**
- ✅ Automatically builds `.deb` package for arm64
- ✅ Auto-detects previous tag for release notes comparison
- ✅ Creates a draft GitHub release with artifacts
- ❌ Does NOT merge back to any branch (automatic mode)

**Tag format:** Must match `v*.*.*` (e.g., `v0.1.0`, `v1.2.3`, `v2.0.0-beta.1`)

#### 2. Manual Workflow Dispatch

**Advanced control** - Manually trigger the workflow via GitHub Actions UI:

```
Actions → Package and Release → Run workflow
```

**Required inputs:**
- `ref`: Git ref to checkout (e.g., `refs/tags/v0.1.0` or branch name)
- `previous`: Previous tag for release notes comparison (e.g., `v0.0.9`)

**Optional inputs:**
- `source_branch`: Branch to merge the tag back to (e.g., `main`)

**What happens:**
- ✅ Builds `.deb` package for arm64
- ✅ Uses your specified previous tag for release notes
- ✅ Creates a draft GitHub release with artifacts
- ✅ Optionally merges tag back to source branch (if `source_branch` provided)

#### 3. Merge to Release Branch (Not Yet Implemented)

Currently, merging a PR to a release branch (e.g., `v0.1.x`) does NOT automatically trigger the workflow. This is a planned feature.

### Workflow Jobs

The workflow consists of three jobs:

#### Job 1: `package-deb`
- Checks out the specified tag/ref
- Extracts version information
- Prepares package structure (scripts, udev rules, maintainer scripts)
- Builds Debian package using `jiro4989/build-deb-action@v4`
- Uploads `.deb` as artifact

#### Job 2: `release`
- Downloads `.deb` artifacts from `package-deb`
- Auto-detects previous tag (automatic mode) or uses provided input (manual mode)
- Generates release notes comparing current tag with previous tag
- Creates a **draft** GitHub release with:
  - Version number as release name
  - Generated release notes
  - `.deb` package artifacts

#### Job 3: `merge-back` (Conditional)
- **Only runs** when manually triggered with `source_branch` input
- Checks out the source branch
- Imports GPG key for signed commits
- Merges the tag back to the source branch:
  - Attempts fast-forward merge first
  - Falls back to merge commit if fast-forward not possible
- Pushes updated branch to origin

### Conditional Logic

The workflow uses conditional logic to handle both automatic and manual triggers:

```yaml
# Ref resolution - uses manual input if available, otherwise uses pushed tag
ref: ${{ github.event.inputs.ref || github.ref }}

# Previous tag detection - auto-detects for automatic triggers
if [ -z "${{ github.event.inputs.previous }}" ]; then
  # Auto-detect previous tag
else
  # Use provided input
fi

# Merge-back - only runs when source_branch is provided
if: github.event.inputs.source_branch != ''
```

### Required Secrets

The workflow requires the following secrets to be configured:

- `GITHUB_TOKEN` - Automatically provided by GitHub Actions
- `GPG_PRIVATE_KEY` - For signing commits during merge-back (optional, only needed for manual dispatch with merge-back)
- `GPG_PASSPHRASE` - Passphrase for GPG key (optional, only needed for manual dispatch with merge-back)

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
