# homepi-server: Architecture Reference

A snapshot of what the repository *is*, rewritten in place on each documentation run. Where prose docs and code disagree, the code is treated as correct and the disagreement is logged in the tech-debt register. Claims not confirmed directly in files are marked *inferred*. Nothing was executed; everything below is read from files.

## 1. Context and scope

`homepi-server` is a Debian meta-package (`arch: arm64`) for a Raspberry Pi. It contains no application code. It is a set of bash scripts, a udev rule, systemd units, a profile.d snippet and Debian maintainer scripts that configure a Pi as a headless home server. Components are added incrementally, per `PLAN.md`.

Components shipped today:

| Component | What it does |
|---|---|
| USB automount | udev rule triggers `usb-automount.sh`, which mounts USB partitions under `/media` and writes `/etc/fstab` entries. |
| Maestral | Dropbox client, pip-installed into `/opt/maestral-venv` by `postinst`. Run per user by the systemd template `maestral@.service`. |
| rclone Google Drive sync | rclone is installed by `postinst`. A push path (inotify) and a pull path (systemd timer, `bisync`) keep `/data/GoogleDrive` and `gdrive:` in sync. An interactive wizard, `homepi-gdrive-setup`, does the OAuth and first sync. |
| Locale handling | `postinst` generates `en_US.UTF-8` and sets it as the system default. `/etc/profile.d/locale-sanitize.sh` unsets a macOS-injected `LC_CTYPE=UTF-8`. |

External systems:

- **Target host.** A Raspberry Pi running Debian (the `postinst` comments mention Bookworm), with udev, systemd, `/etc/fstab` and `blkid`.
- **Remote services.** Dropbox API (via Maestral); Google Drive API (via rclone); PyPI (pip); `https://rclone.org/install.sh`.
- **GitHub.** Actions, Releases and the Actions REST API, used for build and distribution.
- **Users.** Operators who install the `.deb` with `dpkg -i` and SSH into the Pi.

```
git tag vX.Y.Z --> on-tag-main --(API dispatch)--> package-release --> draft GitHub release (.deb)
PR event       --> pr-package  --> draft pre-release "pr-N" (.deb) + PR comment
dpkg -i .deb   --> /usr/local/bin, /etc/{udev,systemd,profile.d,homepi} + postinst (pip, curl|bash, systemctl)
```

## 2. Quality attributes (evidenced only)

- **Headless operability.** There is no browser on the Pi. The rclone OAuth is done through a manual wizard that prints a URL to open on another device (`homepi-gdrive-setup`). Maestral is installed without its GUI "to avoid PyQt6 build issues on Pi" (`debian/postinst.sh`). Mount, unmount and sync activity is logged to `/var/log/usb-automount.log` and `/var/log/rclone-sync.log`.
- **Idempotent, re-runnable setup.** `homepi-gdrive-setup` states that it skips completed steps. `postinst` guards its changes with checks: venv existence, a grep for `locale.gen`, a grep for the sysctl line, an rclone version check, and a duplicate-UUID fstab check in `usb-automount.sh`.
- **Resilience at boot.** fstab entries are written with `nofail` (`usb-automount.sh`). Services use `Restart=on-failure` with `RestartSec=10` (`maestral@.service`, `rclone-watch-gdrive.service`). Services order after `network-online.target`.
- **Safety on removal.** User data is preserved: `/data/GoogleDrive` and `rclone.conf` are kept, and the destructive deletions in `postrm.sh` are commented out.
- **Sync latency.** The inotify push has a 5 s debounce. The pull timer fires 30 s after each run (`OnUnitActiveSec=30s`) with a 60 s boot delay.
- **Release traceability and gating.** Releases are created as **drafts**, so a human publishes them (`package-release.yml`). `package-release.yml` rejects any ref that is not `refs/tags/vX.Y.Z`. The merge-back commit is GPG-signed.
- **Portability.** ARM64 only (`matrix.arch: [arm64]`). Nothing is evidenced for other architectures.
- Latency, availability and cost targets beyond the above: *not evidenced*. There are no SLOs, health checks or resource limits.

## 3. System shape

Flat repo root plus four subdirectories. There is no build system, language package or test harness.

```
usb-automount.sh, 99-usb-automount.rules   USB automount (udev -> script)
diagnose-disks.sh                          read-only diagnostic (lsblk/udevadm)
install-usb-automount.sh                   non-deb installer, USB automount only
rclone-gdrive-watch.sh                     inotify -> rclone sync loop (push)
homepi-gdrive-setup                        interactive rclone/bisync wizard (no extension)
systemd/   rclone-watch-gdrive.service, rclone-pull-gdrive.service/.timer
maestral/  maestral@.service (template unit), maestral-users (whitelist)
locale/    locale-sanitize.sh
debian/    postinst.sh, prerm.sh, postrm.sh   (renamed to DEBIAN/{postinst,prerm,postrm} at build)
.github/workflows/  five workflows + README.md
PLAN.md, README.md, CONTRIBUTING.md, AGENTS.md, CLAUDE.md, debian/README.md
```

Runtime pieces and how they work:

- **USB automount.**
  - `99-usb-automount.rules` matches `KERNEL=="sd[a-z][0-9]"` and `"sd[a-z]"` with `SUBSYSTEMS=="usb"` on add and remove. It calls `/usr/local/bin/usb-automount.sh <add|remove> %k`.
  - The script skips a whole disk that has partitions. It names the mount point `/media/<LABEL>-<dev>`, or `/media/<dev>` when there is no label.
  - It mounts with `rw,users` (plus `umask=000` for vfat, ntfs and exfat) and appends `UUID=... nofail 0 2` to `/etc/fstab`.
  - On remove it runs `umount -l`, deletes the fstab line by UUID and `rmdir`s the mount point.
- **Maestral.** `postinst` builds the venv and symlinks `/usr/local/bin/maestral`. `maestral@<user>.service` runs `maestral start -f` as that user. `postinst` enables and starts it only for users listed in `/etc/homepi/maestral-users` who already have `~/.config/maestral/maestral.ini`.
- **rclone sync.**
  - `rclone-watch-gdrive.service` runs `rclone-gdrive-watch.sh /data/GoogleDrive gdrive:`. That script runs `inotifywait -m -r`, sleeps 5 s on each event, drains pending events, then runs `rclone sync` (local to remote).
  - `rclone-pull-gdrive.timer` fires `rclone-pull-gdrive.service`, which runs `rclone bisync gdrive: /data/GoogleDrive`.
  - Both units have `User=@@RCLONE_USER@@`, a placeholder that `postinst` replaces with `sed` in `/etc/systemd/system`. The user is `$SUDO_USER`, or the account with uid 1000.
  - `postinst` enables but does **not** start these units. `homepi-gdrive-setup` configures the remote, runs `bisync --resync` when no bisync state is found, then restarts the units.

## 4. Boundaries and dependencies

- **Source tree to package.** The only mapping from repo files to installed paths is the `prepare-deb` shell step in `package-release.yml`. `pr-package.yml` repeats that mapping. `install-usb-automount.sh` is a third, USB-only mapping.
- **Package to host.** Files land in `/usr/local/bin` (scripts), `/etc/udev/rules.d`, `/etc/systemd/system`, `/etc/profile.d` and `/etc/homepi`. `postinst`/`prerm`/`postrm` own all stateful changes: `locale-gen`, `sysctl` (`/etc/sysctl.conf`), `systemctl enable|start|stop`, pip, rclone install, `udevadm reload`.
- **Layering in practice.** The udev rule calls the mount script, which touches `/etc/fstab` and `/media`. systemd units call the rclone and maestral binaries. Maintainer scripts configure everything. No component imports another's code. Cross-component links are only file paths, unit names and the shared `RCLONE_USER` logic.
- **Not allowed or not done.** Nothing enforces boundaries; there is no lint, test or CI check on module interaction.
- **Package metadata.** `depends: udev, python3 (>= 3.7), python3-pip, python3-venv, inotify-tools, curl`. rclone is deliberately **not** a Debian dependency; `postinst` installs it from the official installer when the installed version is below `RCLONE_MIN_VERSION=1.65`.

## 5. Change-impact map

All edges below are traced from path and name references in the files (unit names, script paths, workflow `cp` lines).

| Module | Depends on | Depended on by |
|---|---|---|
| `usb-automount.sh` | `/var/log`, `blkid`, `mount`, `/etc/fstab`, `/media` | `99-usb-automount.rules` (hard-coded `/usr/local/bin/usb-automount.sh`), `install-usb-automount.sh`, both packaging workflows |
| `99-usb-automount.rules` | script path `/usr/local/bin/usb-automount.sh` | `postinst` and `postrm` (`udevadm reload`), packaging workflows, installer |
| `diagnose-disks.sh` | `lsblk`, `udevadm` | installer, packaging workflows (it is read-only and independent of the other scripts) |
| `rclone-gdrive-watch.sh` | `inotifywait`, `rclone`, `/var/log/rclone-sync.log` | `systemd/rclone-watch-gdrive.service` (hard-coded path), packaging workflows |
| `systemd/rclone-*` | scripts above, `/data/GoogleDrive`, `gdrive:` remote, `@@RCLONE_USER@@` placeholder | `postinst` (sed and enable), `prerm`/`postrm` (stop, disable, rm), `homepi-gdrive-setup` (enable and restart) |
| `homepi-gdrive-setup` | `rclone`, `inotifywait`, unit names, `/home/<user>/.config/rclone`, `/home/<user>/.cache/rclone/bisync` | `postinst` (prints it as the next step), packaging workflows |
| `maestral/maestral@.service` | `/opt/maestral-venv` path | `postinst`, `prerm`, `postrm`, packaging workflows |
| `maestral/maestral-users` | none | `postinst`, `prerm` (read `/etc/homepi/maestral-users`), packaging workflows |
| `locale/locale-sanitize.sh` | none | packaging workflows only |
| `debian/*.sh` | all of the above by path and name | `package-release.yml`, `pr-package.yml` (copied to `DEBIAN/`) |
| `package-release.yml` | repo file names, `jiro4989/build-deb-action` | `on-tag-main.yml` (dispatches it by file name) |
| `create-branch-on-minor-tag.yml` -> `on-merge-to-release-branch.yml` -> `on-tag-main.yml` | tag/branch name patterns | the chain between them is *inferred* (see debt item 21) |

**Shared hot spots** (a change here touches many places):

- **The `prepare-deb` block and `depends`/`desc` strings.** They are duplicated verbatim in `package-release.yml` and `pr-package.yml`. A new shipped file must be added to both. `CLAUDE.md` and `PLAN.md` name only `package-release.yml`.
- **Hard-coded paths.** `/usr/local/bin/*`, `/data/GoogleDrive`, `/opt/maestral-venv`, `/var/log/rclone-sync.log`, `/etc/homepi/maestral-users` are repeated across `postinst`, `prerm`, `postrm`, the units and the wizard.
- **The `RCLONE_USER` derivation** (`${SUDO_USER:-$(getent passwd 1000 ...)}`) is duplicated in `postinst.sh` and `homepi-gdrive-setup`.
- **`debian/postinst.sh`.** It is the single point where all components are installed, so any change to it affects every install.
- **Tag naming** (`v[0-9]+.[0-9]+.[0-9]+`, `vX.Y.x` branches) is encoded in four workflows.

## 6. Load-bearing conventions

- **Language and style.** All scripts are bash (the one exception is `locale-sanitize.sh`, which is `#!/bin/sh`). Maintainer scripts use `set -e` and `exit 0` at the end. `postinst`/`prerm` guard their actions on `$1` (`configure`, or `remove`/`upgrade`). `postrm` guards on `purge`/`remove`. Stop and disable calls use `|| true`. `usb-automount.sh` and `rclone-gdrive-watch.sh` do not use `set -e`.
- **Logging.** `usb-automount.sh` has a `log_msg` helper that writes a timestamp to the log file and to stderr. The rclone scripts append to `/var/log/rclone-sync.log`.
- **systemd units live in `systemd/` (rclone) and `maestral/` (Maestral).** This is inconsistent: the Maestral unit sits beside its whitelist file, not in `systemd/`.
- **Placeholder substitution.** Units shipped with `@@RCLONE_USER@@` are rewritten in place by `postinst`.
- **Maintainer scripts are named `*.sh` in the repo and copied without the extension** to `DEBIAN/`.
- **Adding a component.** The checklist is in `CLAUDE.md` and `PLAN.md`: add files, update `prepare-deb`, `postinst`, `prerm`, `postrm`, `depends`, and the docs. Nothing enforces it.
- **Versioning.** `v`-prefixed semver, enforced by tag globs and the regex in `package-release.yml`. Minor tags (`vX.Y.0`) create a `vX.Y.x` branch. Pushes to `vX.Y.x` branches auto-tag the next patch (`on-merge-to-release-branch.yml`).
- **Agent-facing docs.** `AGENTS.md` and `CLAUDE.md` direct readers to read `CONTRIBUTING.md` before changing workflows and to keep it updated.

## 7. Dependencies and build

- **No build step, lockfile, manifest or pinned dependency list.** The artifact is assembled by copying files into `.debpkg/` in CI and invoking `jiro4989/build-deb-action@v4` (package `homepi-server`, `arch: arm64`, maintainer set in the workflow).
- **Package version.** Release builds pass `version: refs/tags/<X.Y.Z>`. PR builds use `0.0.0~pr<N>`.
- **Other workflow actions** (all pinned by major tag or version tag, none by SHA): `actions/checkout@v4`, `upload-artifact@v4`, `download-artifact@v4`, `gableroux/generate-github-release-notes@v0.1.2`, `ncipollo/release-action@v1`, `crazy-max/ghaction-import-gpg@v6`, `actions/github-script@v7`. The `gh` CLI is also used.
- **Runtime dependencies on the Pi.**
  - Debian deps: see section 4.
  - Installed at install time from the network: Maestral and pip, both unpinned (`pip install --upgrade`); rclone via `curl https://rclone.org/install.sh | bash`.
  - Required at run time: systemd, udev, `blkid`, `lsblk`, `locale-gen`.
- **Release and deploy flow.**
  1. Push tag `vX.Y.Z`.
  2. `on-tag-main.yml` finds the previous tag with `git describe --tags --abbrev=0 HEAD^` and dispatches `package-release.yml` on `main` via the REST API.
  3. `package-release.yml` runs three jobs: `package-deb`, `release` (creates a **draft** release and attaches `*.deb`) and `merge-back` (only if `source_branch` is non-empty; merges the tag into that branch with signed commits).
  4. A human publishes the draft. Deployment is a manual `dpkg -i` on the Pi.
- **Why an orchestrator.** `CLAUDE.md`, `CONTRIBUTING.md` and `AGENTS.md` all say it is because Actions reads workflow files from the default branch, not from tags.
- **Repo settings required.** The `GITHUB_TOKEN` needs write workflow permissions (otherwise the dispatch returns 403). Optional secrets `GPG_PRIVATE_KEY` and `GPG_PASSPHRASE` are used by merge-back. These settings live outside the repo, so they were not verified.
- **Branches and tags (from `.git/packed-refs`).**
  - Remote branches: `main`, `v0.1.x`, `v0.2.x`, `v0.3.x`, and feature branches `locale-fix` and `pr-package-workflow`.
  - Tags `v0.0.0` to `v0.3.0` (including `v0.2.1`, `v0.2.2` and `v0.2.3`).
  - A local `roomba-local-control` branch and a stash exist.
- **License.** MPL-2.0 (`LICENSE`).

## 8. Testing and quality

Determined from files only; nothing was run.

- **No tests of any kind.** There are no unit, integration or end-to-end tests, no lint (shellcheck or similar), and no CI job that executes the scripts. `CLAUDE.md` states this explicitly ("no build step, linter, or test suite").
- **CI gates that do exist.**
  - `package-release.yml` validates the tag format.
  - `CONTRIBUTING.md` says "all package files must exist". A missing `cp` source would fail the `prepare-deb` step (*inferred* from GitHub Actions' default `bash -e` shell).
  - `pr-package.yml` builds a `.deb` for every PR event (`opened`, `synchronize`, `reopened`), so a PR that breaks packaging fails its build. The package is published as a draft pre-release `pr-<N>`, with a PR comment linking it. The release, tag and comment are removed when the PR closes (the cleanup job deletes the release and tag; the comment is not deleted).
- **Manual verification tools.** `diagnose-disks.sh` (read-only USB/udev inspection) and the log files. PR test packages are installed on a Pi by hand (the PR comment gives the `dpkg -i` command).
- **Gaps.** Every script, unit and maintainer script is untested. The release chain (`create-branch-on-minor-tag`, `on-merge-to-release-branch`) has no evidence of verification in the repo.

## 9. Cross-cutting concerns

- **Security.**
  - Everything runs as root at install time and in udev. The units run as the target user (`User=`).
  - Auto-mounted drives use `users` and, for FAT/NTFS/exFAT, `umask=000` (world-writable).
  - `postinst` pipes a remote script to bash (`curl https://rclone.org/install.sh | bash || true`), with no checksum.
  - Maestral and pip are unpinned.
  - `postinst` runs `eval echo "~$user"` on usernames read from `/etc/homepi/maestral-users`.
  - Workflow inputs (`github.event.inputs.ref`) are interpolated directly into shell scripts via `${{ }}`. The dispatch needs an authenticated API call or a user with write access, and the `ref` is regex-validated, but only *after* the checkout step.
  - Release is gated by draft status; no package signing was found.
  - Secrets: only the GPG key and passphrase, as GitHub secrets. rclone credentials live in the user's `rclone.conf` (outside the repo).
  - No secrets are in the repo. `.claude/settings.local.json` holds local tool permissions only.
- **Configuration.** There is no config system. Behavior is hard-coded in script variables (`DEBOUNCE=5`, `RCLONE_MIN_VERSION`, paths). The only runtime-editable input is `/etc/homepi/maestral-users`. System-wide changes: `/etc/locale.gen`, `/etc/sysctl.conf` (`fs.inotify.max_user_watches=524288`), `/etc/fstab` (written by the udev handler).
- **Logging and observability.** Plain text log files (no rotation configured; "log management" is a `PLAN.md` phase 5 item) plus journald for the systemd units. No metrics or health checks (Prometheus is planned in `PLAN.md` phase 1).
- **Error propagation.** Maintainer scripts abort on error because of `set -e`, except where explicitly `|| true` (rclone install, service start and stop). `usb-automount.sh` logs failures and continues; it exits non-zero only for missing parameters or an already-mounted device.
- **Concurrency.** The push (`rclone sync`) and pull (`rclone bisync`, every 30 s) paths act on the same directory pair from separate units. No locking between them was found in the repo. The fstab edit in `usb-automount.sh` has no lock either.

## 10. Key design decisions and why

- **Orchestrator plus worker workflows.** `on-tag-main.yml` dispatches `package-release.yml` on `main`. Reason as stated in the docs: Actions reads workflows from the default branch, not from tags.
- **rclone is installed by `postinst` via the official script instead of a Debian dependency.** The comment says apt rclone on Bookworm is 1.60, too old for `bisync`. `RCLONE_MIN_VERSION=1.65` guards this. The version probe uses `rclone --version` rather than `rclone version --check`; the comment says the latter exits non-zero when up to date and breaks the parse (commit `7f81b2a`).
- **Maestral in an isolated venv without GUI.** The stated reason is to avoid PyQt6 build issues on a Pi. The venv path is hard-coded in `maestral@.service`.
- **rclone services are enabled but not started at install.** The Pi has no browser, so OAuth must happen first via `homepi-gdrive-setup`.
- **Placeholder `@@RCLONE_USER@@`.** The units are rewritten at install time because the target user is not known at build time (*inferred*; the files do not state the reason).
- **Duplicate whole-disk and partition udev rules.** `sd[a-z]` and `sd[a-z][0-9]` are both matched. The script skips a whole disk when partitions exist, so unpartitioned disks still mount (comment in the rules and script).
- **`umount -l` (lazy).** The code does not give a reason. The intent is not established.
- **Locale sanitizer and `postinst` locale generation.** The sanitizer addresses macOS SSH sending `LC_CTYPE=UTF-8` (`locale-sanitize.sh` comment). The `postinst` locale block has no comment giving its reason.
- **PR packages use a `0.0.0~prN` version and `gh release upload --clobber`.** Commit `4b7ff75` is titled "Fix PR release asset replacement: use gh release upload --clobber"; the workflow keeps `omitArtifactsDuringUpdate: true` on the release action. The tilde sorts the version below any real release (Debian version semantics).
- **ADRs.** None exist. There is no `docs/` directory apart from this file.

## 11. Tech-debt register

Every item is described neutrally. Status is "unknown" unless evidence says otherwise.

| # | Item | Evidence | Status |
|---|---|---|---|
| 1 | `CONTRIBUTING.md` says merging to a release branch is "Not Yet Implemented", but `on-merge-to-release-branch.yml` exists and tags the next patch. (#8) | `CONTRIBUTING.md` "Merge to Release Branch"; `.github/workflows/on-merge-to-release-branch.yml` | unknown |
| 2 | `.github/workflows/README.md` and `CONTRIBUTING.md` say `create-branch-on-minor-tag.yml` triggers `package-release.yml`. The workflow only creates the branch. (#9) | `create-branch-on-minor-tag.yml` | unknown |
| 3 | The docs list 2 or 3 workflows and no `pr-package.yml` or `on-merge-to-release-branch.yml` (`CLAUDE.md` says "Three workflows"; there are five). (#10) | `CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md` | unknown |
| 4 | Package contents and dependencies are out of date in the docs: `CONTRIBUTING.md` omits `inotify-tools`, `curl`, rclone, the Maestral service and the locale files. `debian/README.md` and `README.md` omit rclone, Google Drive, locale and the units. `AGENTS.md` omits rclone. `.github/workflows/README.md` lists 4 deps. (#11) | those files vs `package-release.yml` | unknown |
| 5 | `debian/README.md` says to push a tag and then "Run workflow manually", but tag pushes dispatch automatically. `CONTRIBUTING.md` lists merge-back as an automatic step 6 of the tag flow and also as an "optional ... manual" step in its release process. The orchestrator always sends `source_branch: main`. (#12) | `debian/README.md`, `CONTRIBUTING.md`, `on-tag-main.yml` | unknown |
| 6 | `PLAN.md` Phase 3 lists "extend USB automount to optionally write fstab entries" as future work. `usb-automount.sh` already writes and removes them. (#13) | `PLAN.md`, `usb-automount.sh` `add_fstab_entry` | unknown |
| 7 | `README.md`, `CLAUDE.md` and `diagnose-disks.sh` imply the udev rules require `removable=1`. The rules do not test `removable`; they match `SUBSYSTEMS=="usb"`. (#14) | `99-usb-automount.rules` | unknown |
| 8 | `CLAUDE.md` and `PLAN.md` name only `package-release.yml` as the place to add new shipped files; `pr-package.yml` has its own copy of the same step. (#15) | `pr-package.yml`, `CLAUDE.md` "Adding New Components" | unknown |
| 9 | Duplicated packaging logic (`prepare-deb` copy block, `depends`, `desc`) in two workflows, plus a third USB-only installer. (#16) | `package-release.yml`, `pr-package.yml`, `install-usb-automount.sh` | accepted (no tracking evidence) |
| 10 | `maestral/maestral-users` ships with `fix` uncommented, while the packaging step's comment says "default empty" and the file header describes examples only. (#17) | `maestral/maestral-users`, `package-release.yml` | unknown |
| 11 | `package-release.yml` passes `version: refs/tags/<X.Y.Z>` (a ref prefix and no `v`) to the build action; the ref is validated only after checkout; `permissions` and `env.GITHUB_TOKEN` are declared at workflow and job level redundantly. (#18) | `package-release.yml` | unknown |
| 12 | `usb-automount.sh` details: `mount \| grep "${DEVICE}"` is a substring match, so `sda1` also matches `sda10`; `blkid ... 2>&1` captures stderr into LABEL and FSTYPE; there is no locking around `/etc/fstab`. (#19) | `usb-automount.sh` (`MOUNT_POINT=`, `LABEL=`, `FSTYPE=` lines) | unknown |
| 13 | On remove, the UUID is read with `blkid` from a device that may already be gone, so the fstab line may not be removed. *Inferred* from udev remove semantics, not confirmed in code. (#20) | `usb-automount.sh` `do_unmount` | unknown |
| 14 | The push path runs `rclone sync` (mirrors deletes) while the pull path runs `rclone bisync`, both on the same tree with no coordination. (#21) | `rclone-gdrive-watch.sh`, `systemd/rclone-pull-gdrive.service` | unknown |
| 15 | `postrm.sh` runs `cleanup_maestral` and `cleanup_rclone_services` on both `remove` and `purge`, so the Maestral venv and the unit files are deleted on plain `remove`. Its message says configuration is "preserved", and `debian/README.md` says "Remove package but keep configuration". (#22) | `debian/postrm.sh`, `debian/README.md` | unknown |
| 16 | `homepi-gdrive-setup` hard-codes `/home/${RCLONE_USER}` rather than resolving the home directory. (#23) | `homepi-gdrive-setup` | unknown |
| 17 | Location and naming inconsistency: the Maestral unit is in `maestral/`, rclone units in `systemd/`; `homepi-gdrive-setup` is extensionless while other scripts are `.sh`. (#24) | tree | accepted |
| 18 | `.claude/settings.local.json` is present in the working tree and references personal NAS MCP tools; whether it is git-tracked was not determined (no `.gitignore` found). (#25) | `.claude/settings.local.json` | unknown |
| 19 | A local `roomba-local-control` branch and a stash exist, with no related files on `main`. (#26) | `.git/packed-refs` | unknown |
| 20 | No tests or linting of any script. (#27) | whole repo | accepted (stated in `CLAUDE.md`) |
| 21 | The `v*.x` auto-tag chain relies on a tag or branch pushed with `GITHUB_TOKEN` triggering further workflows. GitHub normally suppresses those events (*inferred* from platform behavior, not confirmed here). Tags `v0.2.1` to `v0.2.3` exist, so some path produced them. (#28) | `create-branch-on-minor-tag.yml`, `on-merge-to-release-branch.yml`, `.git/packed-refs` | unknown |

Tracking: epic #7. Per-item issues are linked in the Item column (#8 to #28).

## 12. When documented

- Date: 2026-11-03.
- Commit: `8486a404ae39849ca52791cc2fecedaddf62f831` (branch `main`, per `.git/HEAD` and `.git/packed-refs`; the same commit as tag `v0.3.0` and `origin/v0.3.x`). The working tree was clean at the start of the run.
- Index of existing docs: `README.md` (overview and USB/Maestral usage), `debian/README.md` (maintainer scripts and package), `CONTRIBUTING.md` (release process, secrets), `PLAN.md` (roadmap), `AGENTS.md` and `CLAUDE.md` (agent guidance), `.github/workflows/README.md` (workflow summary). No ADRs.
