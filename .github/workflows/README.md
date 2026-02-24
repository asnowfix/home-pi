# GitHub Actions Workflows

This directory contains automated workflows for building, packaging, and releasing the home-pi project.

## Workflows

### 1. `on-tag-main.yml` - Trigger Release on Tag Push

**Trigger**: When a tag matching `v*.*.*` is pushed (e.g., `v0.1.0`, `v1.2.3`)

**Actions**:
- Detects the previous tag
- Triggers the `package-release.yml` workflow with the tag reference

**Example**:
```bash
git tag v0.1.0
git push origin v0.1.0
```

### 2. `create-branch-on-minor-tag.yml` - Auto-create Version Branches

**Trigger**: When a tag matching `v*.*.0` is pushed (e.g., `v0.1.0`, `v1.0.0`)

**Actions**:
- Extracts major and minor version from tag
- Creates a version branch named `vMAJOR.MINOR.x` (e.g., `v0.1.x`)
- Triggers the `package-release.yml` workflow

**Example**:
```bash
git tag v0.1.0
git push origin v0.1.0
# Creates branch v0.1.x automatically
```

**Permissions**: `contents: write` - Required to create and push branches

### 3. `package-release.yml` - Build and Release Debian Packages

**Trigger**: Manual workflow dispatch (triggered by other workflows)

**Inputs**:
- `ref`: Git ref to checkout (tag or branch)
- `previous`: Previous ref/tag for release notes
- `source_branch`: Optional branch to merge back to after release

**Jobs**:

#### `package-deb`
- Builds ARM64 Debian package
- Installs USB automount scripts and udev rules
- Installs Maestral Dropbox client via pip
- Uploads package as artifact

#### `release`
- Downloads built packages
- Generates release notes
- Creates draft GitHub release with attached `.deb` files

#### `merge-back`
- Merges tag back to source branch (if specified)
- Requires GPG signing (optional, can be removed)

**Permissions**: 
- `contents: write` - Required for creating releases and pushing branches
- `packages: write` - Required for package operations

## Workflow Flow

### Standard Release (e.g., v0.1.1, v0.2.5)

```
1. Developer pushes tag: git push origin v0.1.1
2. on-tag-main.yml triggers
3. package-release.yml builds and creates draft release
4. Developer reviews and publishes release on GitHub
```

### Minor Version Release (e.g., v0.1.0, v1.0.0)

```
1. Developer pushes tag: git push origin v0.1.0
2. create-branch-on-minor-tag.yml triggers
3. Creates branch v0.1.x
4. package-release.yml builds and creates draft release
5. Developer reviews and publishes release on GitHub
```

## Permissions

All workflows require proper GitHub token permissions to avoid 403 errors:

- **Workflow-level**: `contents: write`, `packages: write`
- **Job-level**: Specific permissions for each job

The `GITHUB_TOKEN` is automatically provided by GitHub Actions and has the necessary permissions when configured correctly.

## Troubleshooting

### Error 403: Resource not accessible by integration

**Solution**: Ensure the workflow has proper permissions set:
```yaml
permissions:
  contents: write
  packages: write
```

### Branch creation fails

**Solution**: Check that the workflow has `contents: write` permission and the branch doesn't already exist.

### Release notes generation fails

**Solution**: Ensure the `previous` tag exists and is accessible. The workflow uses the previous tag to generate release notes.

## Dependencies

The Debian package requires:
- `udev` - For USB device detection
- `python3 (>= 3.7)` - For Maestral
- `python3-pip` - For installing Maestral
- `python3-venv` - For Maestral virtual environment

## Manual Workflow Trigger

You can manually trigger the package-release workflow from GitHub:

1. Go to Actions → Package and Release
2. Click "Run workflow"
3. Fill in:
   - **ref**: `refs/tags/v0.1.0` (or branch)
   - **previous**: `v0.0.1` (previous tag)
   - **source_branch**: `main` (optional)
