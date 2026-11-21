# Mystic GSI

Build pipeline that produces a flashable Android **Generic System Image (GSI)** with **GitHub Actions**.

The workflow syncs an AOSP-derived Treble manifest, builds the requested `treble_*` lunch target, compresses `system.img`, checksums it, uploads it as an artifact, and optionally publishes a GitHub release.

> This repository contains **no source code and no proprietary blobs**. It is a thin, configurable CI wrapper around an upstream manifest (TrebleDroid by default).

## Features

- One-click builds via `workflow_dispatch` (variant, manifest, branch, runner are all inputs).
- `ccache` restored across runs to speed up repeat builds.
- Local patch support without forking every project (`patches/<project>/*.patch`).
- SHA-256 checksums and a `build-info.txt` manifest in every artifact.
- Optional GitHub release publishing.
- `shellcheck` + YAML validation on every push/PR.

## Quick start

1. Push this repository to GitHub (or fork it).
2. Go to **Actions → Build Mystic GSI → Run workflow**.
3. Pick a variant (default `treble_arm64_bvN`) and run it.
4. Download the artifact, or grab the release if `upload_release` is enabled.

Verify the manifest branch exists before your first run:

```bash
git ls-remote --heads https://github.com/TrebleDroid/treble_manifest.git
```

## Requirements

A full AOSP build needs roughly **200 GB of free disk, 16+ cores and 32–64 GB of RAM**, and can take several hours.

| Runner | Expected result |
| --- | --- |
| `ubuntu-latest` (GitHub-hosted, 4 vCPU / 16 GB / ~14 GB free) | Sync will run out of disk. Useful only for testing the pipeline. |
| GitHub larger runner (16–64 cores) | Works; select it through the `runner` input. |
| Self-hosted machine (recommended) | Works; register it with the label you pass to `runner`. |

Set the `runner` input to your label (for example `self-hosted`) when you have one available.

## Workflow inputs

| Input | Default | Purpose |
| --- | --- | --- |
| `variant` | `treble_arm64_bvN` | Lunch target to build (`treble_<arch>_<ab|aonly>_<v|g>N`). |
| `manifest_url` | TrebleDroid `treble_manifest` | Any repo-compatible manifest. |
| `manifest_branch` | `android-14.0.0_r1` | Branch/tag of that manifest. |
| `runner` | `ubuntu-latest` | Runner label used for the build job. |
| `upload_release` | `true` | Publish the image as a GitHub release. |
| `retention_days` | `14` | Artifact retention. |

Variant naming follows the usual Treble convention: `arm64`/`arm32`/`a64` architecture, `b` = A/B, `a` = A-only, `v` = vanilla, `g` = with GApps, `N` = no root/su. Exact target names come from the upstream manifest — check its `device/` tree if a lunch target is rejected.

## Repository layout

```
.
├── .github/workflows/
│   ├── build-gsi.yml        # sync → build → package → artifact/release
│   └── lint.yml             # shellcheck + YAML/shell syntax checks
├── scripts/
│   ├── 00-setup-runner.sh   # frees disk, installs AOSP deps and repo
│   ├── 10-sync.sh           # repo init/sync
│   ├── 20-build.sh          # applies patches, lunch + make systemimage
│   └── 30-package.sh        # xz, sha256, build-info.txt
├── patches/                 # optional per-project patches
├── artifacts/               # output directory (gitignored)
├── source/                  # Android tree (gitignored)
└── README.md
```

## How it works

1. **Prepare runner** — removes unused preinstalled toolchains, installs AOSP dependencies, installs `repo`, configures `ccache`.
2. **Sync** — `repo init --depth=1` + `repo sync -c` into `source/`.
3. **Build** — sources `build/envsetup.sh`, runs `lunch <variant>`, then `make -j systemimage`.
4. **Package** — compresses to `MysticGSI_<variant>_<date>.img.xz`, writes `.sha256` and `build-info.txt`.
5. **Publish** — uploads an artifact and, if enabled, creates a release tagged `mystic-<variant>-<timestamp>`.

## Customizing

### Use a different manifest

Pass `manifest_url` / `manifest_branch` when dispatching. Any manifest that exposes `treble_*` lunch targets works.

### Add patches

Patches are applied with `git apply` inside the matching project directory:

```
patches/
└── frameworks_base/
    └── 0001-mystic-branding.patch
```

The directory name must match the project path in the Android tree (`frameworks/base` → `frameworks_base`). Generate patches with:

```bash
git -C source/frameworks/base format-patch -1 --stdout > patches/frameworks_base/0001-mystic-branding.patch
```

Projects absent from the current manifest are skipped with a warning.

### Build locally

```bash
export MANIFEST_URL=https://github.com/TrebleDroid/treble_manifest.git
export MANIFEST_BRANCH=android-14.0.0_r1
export LUNCH_TARGET=treble_arm64_bvN
export SOURCE_DIR="$PWD/source"

bash scripts/00-setup-runner.sh   # Linux only; skip if your host is already set up
bash scripts/10-sync.sh
bash scripts/20-build.sh
bash scripts/30-package.sh
```

## Troubleshooting

- **`No space left on device`** — the runner is too small. Use a larger or self-hosted runner; the setup script already frees several GB.
- **`repo init` fails on the branch** — list branches with `git ls-remote --heads <manifest_url>` and pass a valid one.
- **`lunch` target not found** — the manifest does not provide that variant; check its device tree.
- **Build killed / job timed out** — the job is capped at 6 hours; AOSP on slow hardware exceeds that. Raise `timeout-minutes` if your runner allows it.
- **Large artifact upload fails** — publish a release instead of relying on artifacts, which have retention and size limits.

## Disclaimer

Flashing a GSI can brick a device or wipe data. These images are built from third-party upstream sources and are provided **as-is, without warranty**. Back up first and know how to restore your device.

## License

MIT — see [LICENSE](LICENSE). Upstream sources keep their own licenses (mostly Apache-2.0).
