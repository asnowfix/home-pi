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
