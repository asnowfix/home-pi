# AI Coding Agents Guide

## Project Documentation

Before making changes to this repository, **read the following documentation:**

- **[CONTRIBUTING.md](CONTRIBUTING.md)** - Release workflow, package build process, and development guidelines
  - Understand the orchestrator pattern architecture
  - Learn about the two-workflow system (on-tag-main.yml + package-release.yml)
  - Review how tag pushes trigger automated releases
  - Check required secrets and configuration
- **[PLAN.md](PLAN.md)** - Roadmap for expanding the meta-package with new components

## Project Overview

`homepi-server` is a **meta-package** for Raspberry Pi. It ships scripts, configuration files, and dependencies to turn a Pi into a home server. Components are added incrementally — see PLAN.md for the roadmap.

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

The `homepi-server` meta-package currently includes:
- USB automount: `usb-automount.sh`, `99-usb-automount.rules`
- Diagnostics: `diagnose-disks.sh`
- Maestral Dropbox client (installed via postinst)
- Maintainer scripts: `debian/postinst.sh`, `debian/prerm.sh`, `debian/postrm.sh`

All files must exist and be properly formatted for the package build to succeed.

## Required Configuration

**Repository Workflow Permissions:**

The orchestrator pattern requires write permissions for `GITHUB_TOKEN` to trigger workflows via API.

**Quick Setup (gh CLI):**
```bash
# Set permissions
gh api --method PUT \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  /repos/asnowfix/home-pi/actions/permissions \
  -F enabled=true \
  -f default_workflow_permissions='write' \
  -F can_approve_pull_request_reviews=false

# Verify (should return: {"enabled": true, "allowed_actions": "all", ...})
gh api -H "Accept: application/vnd.github+json" \
  /repos/asnowfix/home-pi/actions/permissions
```

**Alternative:** Repository Settings → Actions → Workflow permissions → "Read and write permissions"

**Critical:** Without this, orchestrator workflows fail with 403 errors when dispatching package builds.

## Required Secrets

- `GITHUB_TOKEN` - Auto-provided by GitHub Actions
- `GPG_PRIVATE_KEY` - For signed commits (merge-back only)
- `GPG_PASSPHRASE` - For GPG key (merge-back only)
