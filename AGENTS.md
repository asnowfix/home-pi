# AI Coding Agents Guide

## Project Documentation

Before making changes to this repository, **read the following documentation:**

- **[CONTRIBUTING.md](CONTRIBUTING.md)** - Release workflow, package build process, and development guidelines
  - Understand the orchestrator pattern architecture
  - Learn about the two-workflow system (on-tag-main.yml + package-release.yml)
  - Review how tag pushes trigger automated releases
  - Check required secrets and configuration

## Key Workflow Information

### Release Automation Architecture

This project uses an **orchestrator pattern** with two workflows:

1. **`on-tag-main.yml`** (Orchestrator)
   - Triggers on tag push matching `v[0-9]+.[0-9]+.[0-9]+`
   - Auto-detects previous tag
   - Dispatches `package-release.yml` via GitHub API

2. **`package-release.yml`** (Worker)
   - Triggered only via `workflow_dispatch`
   - Builds Debian packages for arm64
   - Creates draft releases with auto-generated release notes
   - Optionally merges back to source branch

### Important: Why the Orchestrator Pattern?

GitHub Actions reads workflow files from the **default branch** (main), not from tags. The orchestrator pattern ensures:
- Workflow files on `main` are always used
- Tags can be created from any commit
- Proper context is maintained for builds

### Tag Format

All version tags must match the pattern `v*.*.*` (e.g., `v0.1.0`, `v1.2.3`).

## Making Changes

1. **Read CONTRIBUTING.md first** to understand the release process
2. **Test workflow changes** carefully - they affect automatic releases
3. **Maintain backward compatibility** with both automatic and manual triggers
4. **Document any workflow changes** in CONTRIBUTING.md

## Package Structure

The project builds a Debian package with:
- Main script: `usb-automount.sh`
- udev rules: `99-usb-automount.rules`
- Maintainer scripts: `debian/postinst.sh`, `debian/prerm.sh`, `debian/postrm.sh`

All files must exist and be properly formatted for the package build to succeed.

## Required Configuration

**Repository Settings:**
- Workflow permissions must be set to **"Read and write permissions"**
- Configure at: Repository Settings → Actions → Workflow permissions

## Required Secrets

- `GITHUB_TOKEN` - Auto-provided by GitHub Actions
- `GPG_PRIVATE_KEY` - For signed commits (merge-back only)
- `GPG_PASSPHRASE` - For GPG key (merge-back only)
