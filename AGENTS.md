# AI Coding Agents Guide

## Project Documentation

Before making changes to this repository, **read the following documentation:**

- **[CONTRIBUTING.md](CONTRIBUTING.md)** - Release workflow, package build process, and development guidelines
  - Understand the automated Package and Release workflow
  - Learn about the three trigger methods (push tag, manual dispatch, PR merge)
  - Review conditional logic for automatic vs manual triggers
  - Check required secrets and configuration

## Key Workflow Information

### Release Automation

This project uses `.github/workflows/package-release.yml` which:

1. **Triggers automatically** when you push a tag matching `v*.*.*`
2. **Can be manually triggered** via workflow_dispatch with custom inputs
3. **Builds Debian packages** for arm64 architecture
4. **Creates draft releases** with auto-generated release notes
5. **Optionally merges back** to source branch (manual mode only)

### Important: Conditional Logic

The workflow uses `${{ github.event.inputs.ref || github.ref }}` pattern throughout to support both:
- **Automatic triggers**: Uses `github.ref` (the pushed tag)
- **Manual triggers**: Uses `github.event.inputs.ref` (user-provided input)

When modifying the workflow, maintain this pattern to ensure both trigger methods work correctly.

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

## Required Secrets

- `GITHUB_TOKEN` - Auto-provided by GitHub Actions
- `GPG_PRIVATE_KEY` - For signed commits (merge-back only)
- `GPG_PASSPHRASE` - For GPG key (merge-back only)
