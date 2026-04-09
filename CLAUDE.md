# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**homepi-server** is a Debian meta-package (ARM64) that ships scripts, configuration files, and dependencies to turn a Raspberry Pi into a home server. Components are added incrementally — see PLAN.md for the roadmap.

Current components:
1. **USB Automount** - udev-triggered script that auto-mounts/unmounts USB drives to `/media/<label>-<device>`
2. **Maestral** - Dropbox sync client installed in an isolated Python venv at `/opt/maestral-venv/`

## Key Files

- `usb-automount.sh` - Core mount/unmount handler, invoked by udev with `add|remove <device>` args
- `99-usb-automount.rules` - udev rules matching removable USB devices (`sd[a-z][0-9]`, `SUBSYSTEMS=="usb"`)
- `diagnose-disks.sh` - Troubleshooting tool for USB detection issues
- `install-usb-automount.sh` - Manual (non-deb) installation script
- `debian/postinst.sh`, `debian/prerm.sh`, `debian/postrm.sh` - Debian package lifecycle hooks

## Installation & Testing

```bash
# Manual install (on a Raspberry Pi)
sudo ./install-usb-automount.sh

# Install from .deb
sudo dpkg -i homepi-server_*.deb

# Monitor automount activity
tail -f /var/log/usb-automount.log

# Run diagnostics
sudo ./diagnose-disks.sh
```

There is no build step, linter, or test suite. All scripts are bash.

## CI/CD: Orchestrator Pattern

The release system uses an **orchestrator pattern** because GitHub Actions reads workflow files from `main`, not from tags.

### Three workflows in `.github/workflows/`:

1. **`on-tag-main.yml`** (Orchestrator) - Triggers on semver tag push (`v*.*.*`), finds previous tag, dispatches the worker via GitHub API
2. **`package-release.yml`** (Worker) - `workflow_dispatch` only. Builds ARM64 .deb via `jiro4989/build-deb-action@v4`, creates draft GitHub release, optionally merges tag back to source branch
3. **`create-branch-on-minor-tag.yml`** - On minor version tags (`v*.*.0`), creates a `vX.Y.x` release branch and triggers packaging

### Release flow

```bash
git tag v0.1.0
git push origin v0.1.0
# Orchestrator auto-detects previous tag and dispatches worker
# Worker builds .deb, creates draft release
```

### Required repo config

- `GITHUB_TOKEN` needs **write** workflow permissions (Settings > Actions > Workflow permissions) or the orchestrator gets 403 errors
- Optional secrets: `GPG_PRIVATE_KEY`, `GPG_PASSPHRASE` (for signed merge-back commits)

## Adding New Components

When adding a new component to the meta-package:
1. Add scripts/config files to the repo root (or a subdirectory for complex components)
2. Update `package-release.yml` → `prepare-deb` step to copy files into `.debpkg/`
3. Update `debian/postinst.sh` to configure the component on install
4. Update `debian/prerm.sh` and `debian/postrm.sh` for cleanup
5. Add dependencies to the `depends` field in `build-deb` step if needed
6. Update PLAN.md to reflect progress

## Development Guidelines (from AGENTS.md)

- Read CONTRIBUTING.md before modifying workflows
- Test workflow changes carefully - they affect automatic releases
- Maintain backward compatibility with both automatic and manual workflow triggers
- Document any workflow changes in CONTRIBUTING.md
- All package files must exist and be properly formatted: `usb-automount.sh`, `diagnose-disks.sh`, `99-usb-automount.rules`, `debian/*.sh`

## Versioning

Semantic versioning with `v` prefix: `v1.2.3`. Tags must match `v[0-9]+.[0-9]+.[0-9]+`.
